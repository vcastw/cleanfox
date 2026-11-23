#!/usr/bin/env python3
"""Teste de rede: abre o navegador com um perfil novo, sem tocar em nada, e registra
TODA conexão que ele abre (um proxy local anota o destino de cada CONNECT/GET).

Falha se aparecer um host fora de tests/allowed-hosts.txt — cada host lá tem o motivo.
Uso: tests/check-network.py /caminho/para/cleanfox [segundos] [--also-allow HOST ...]
     (padrão: 120 s). --also-allow é para quando o binário testado não é o CleanFox
     (ex.: o Firefox oficial com a configuração aplicada, que tem o atualizador da Mozilla).

Se a máquina já sai por um proxy (HTTPS_PROXY), o teste encadeia nele. Se esse proxy
intercepta TLS, aponte CLEANFOX_TEST_EXTRA_CA para a CA dele (como em check-extensions.py).
"""
import asyncio
import os
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent
UPSTREAM = urlsplit(os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy") or "")
seen = {}


async def pipe(reader, writer):
    try:
        while data := await reader.read(65536):
            writer.write(data)
            await writer.drain()
    except (ConnectionError, asyncio.CancelledError):
        pass
    finally:
        writer.close()


async def handle(client_r, client_w):
    head = await client_r.readuntil(b"\r\n\r\n")
    method, target = head.split(b" ", 2)[:2]
    host = target.decode() if method == b"CONNECT" else urlsplit(target.decode()).netloc
    host = host.rsplit(":", 1)[0] if host.count(":") == 1 else host
    seen[host] = seen.get(host, 0) + 1
    try:
        if UPSTREAM.hostname:  # encadeia no proxy da máquina, repassando o pedido como veio
            up_r, up_w = await asyncio.open_connection(UPSTREAM.hostname, UPSTREAM.port)
            up_w.write(head)
        elif method == b"CONNECT":
            h, _, p = target.decode().rpartition(":")
            up_r, up_w = await asyncio.open_connection(h, int(p))
            client_w.write(b"HTTP/1.1 200 Connection established\r\n\r\n")
        else:
            u = urlsplit(target.decode())
            up_r, up_w = await asyncio.open_connection(u.hostname, u.port or 80)
            up_w.write(head.replace(target, (u.path or "/").encode() + (b"?" + u.query.encode() if u.query else b""), 1))
    except OSError:
        client_w.close()
        return
    await asyncio.gather(pipe(client_r, up_w), pipe(up_r, client_w))


def run_proxy(ready):
    loop = asyncio.new_event_loop()
    server = loop.run_until_complete(asyncio.start_server(handle, "127.0.0.1", 0))
    ready.append(server.sockets[0].getsockname()[1])
    loop.run_forever()


def allowed_hosts():
    hosts = {}
    for line in (ROOT / "tests/allowed-hosts.txt").read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            host, _, why = line.partition(" ")
            hosts[host] = why.strip()
    return hosts


def main():
    args, extra = sys.argv[1:], {}
    while "--also-allow" in args:
        i = args.index("--also-allow")
        extra[args[i + 1]] = "permitido só nesta execução (--also-allow)"
        del args[i:i + 2]
    if len(args) not in (1, 2):
        sys.exit(__doc__)
    binary = args[0]
    seconds = int(args[1]) if len(args) == 2 else 120
    ready = []
    threading.Thread(target=run_proxy, args=(ready,), daemon=True).start()
    while not ready:
        time.sleep(0.05)
    port = ready[0]

    with tempfile.TemporaryDirectory() as profile:
        prefs = {
            "network.proxy.type": 1, "network.proxy.http": "127.0.0.1", "network.proxy.http_port": port,
            "network.proxy.ssl": "127.0.0.1", "network.proxy.ssl_port": port,
            "network.proxy.no_proxies_on": "", "network.proxy.allow_hijacking_localhost": True,
        }
        extra_ca = os.environ.get("CLEANFOX_TEST_EXTRA_CA")
        if extra_ca:
            db = f"sql:{profile}"
            subprocess.run(["certutil", "-N", "--empty-password", "-d", db], check=True)
            subprocess.run(["certutil", "-A", "-n", "test-extra-ca", "-t", "C,,", "-i", extra_ca, "-d", db], check=True)
            prefs["security.cert_pinning.enforcement_level"] = 1  # ver check-extensions.py
        js = lambda v: "true" if v is True else str(v) if isinstance(v, int) else f'"{v}"'
        Path(profile, "user.js").write_text("".join(f'user_pref("{k}", {js(v)});\n' for k, v in prefs.items()))
        proc = subprocess.Popen([binary, "--headless", "--no-remote", "--profile", profile],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(seconds)
        proc.terminate()
        try:
            proc.wait(timeout=20)
        except subprocess.TimeoutExpired:
            proc.kill()

    allowed = allowed_hosts() | extra
    unknown = []
    print(f"Conexões em {seconds} s:")
    for host, n in sorted(seen.items(), key=lambda kv: -kv[1]):
        why = allowed.get(host)
        print(f"  {n:4}  {host}  — {why or 'NÃO PERMITIDO'}")
        if why is None:
            unknown.append(host)
    if unknown:
        sys.exit("FALHA: conexões fora de tests/allowed-hosts.txt: " + ", ".join(unknown))
    print("OK")


if __name__ == "__main__":
    main()
