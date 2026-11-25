#!/usr/bin/env python3
"""Teste de runtime: sobe um Firefox/ColdFox real (headless) que já tenha a
configuração aplicada e confere, via Marionette, que:

  * toda pref de settings/coldfox.js tem o valor esperado (e está travada, se `locked`);
  * as políticas de policies.json estão ativas e foram aceitas sem erro.

Uso: tests/check-runtime.py /caminho/para/firefox   (o executável)
"""
import json
import re
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PORT = 2828

PREF_RE = re.compile(r'^pref\("([^"]+)", (.+?)(, locked)?\);$')


def expected_prefs():
    prefs = []
    for line in (ROOT / "settings/coldfox.js").read_text().splitlines():
        m = PREF_RE.match(line)
        if m:
            raw = m[2]
            value = raw[1:-1] if raw.startswith("'") else json.loads(raw)  # '...' guarda JSON
            prefs.append({"name": m[1], "value": value, "locked": bool(m[3])})
    return prefs


def temp_profile():
    # No Windows o navegador pode ainda segurar arquivos do perfil por um instante.
    return tempfile.TemporaryDirectory(ignore_cleanup_errors=True)


def start(binary, profile, *extra):
    args = [binary, "--headless", "--no-remote", *extra, "--profile", profile]
    if sys.platform == "win32":
        # O .exe do Windows é um lançador que abre o navegador em outro processo;
        # com isto ele fica vivo até o navegador sair e stop() alcança os dois.
        args.insert(1, "-wait-for-browser")
    return subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def stop(proc):
    if sys.platform == "win32":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True)
    else:
        proc.terminate()
    try:
        proc.wait(timeout=20)
    except subprocess.TimeoutExpired:
        proc.kill()


class Marionette:
    def __init__(self, port, timeout=90):
        deadline = time.time() + timeout
        while True:
            try:
                self.sock = socket.create_connection(("127.0.0.1", port), timeout=30)
                break
            except OSError:
                if time.time() > deadline:
                    raise
                time.sleep(0.5)
        self.buf = b""
        self.msg_id = 0
        self._recv()  # handshake

    def _recv(self):
        while b":" not in self.buf:
            self.buf += self._read()
        length, _, rest = self.buf.partition(b":")
        length = int(length)
        while len(rest) < length:
            rest += self._read()
        self.buf = rest[length:]
        return json.loads(rest[:length])

    def _read(self):
        chunk = self.sock.recv(65536)
        if not chunk:
            raise ConnectionError("Marionette fechou a conexão")
        return chunk

    def send(self, command, params=None):
        self.msg_id += 1
        payload = json.dumps([0, self.msg_id, command, params or {}]).encode()
        self.sock.sendall(str(len(payload)).encode() + b":" + payload)
        _type, _id, error, result = self._recv()
        if error:
            raise RuntimeError(f"{command}: {error}")
        return result


CHROME_SCRIPT = """
const [prefs] = arguments;
const P = Services.prefs;
const read = name => {
  switch (P.getPrefType(name)) {
    case P.PREF_BOOL: return P.getBoolPref(name);
    case P.PREF_INT: return P.getIntPref(name);
    case P.PREF_STRING: return P.getStringPref(name);
    default: return null;
  }
};
return {
  prefs: prefs.map(p => ({name: p.name, value: read(p.name), locked: P.prefIsLocked(p.name)})),
  policyStatus: Services.policies.status,
  policyActive: Services.policies.ACTIVE,
  activePolicies: Object.keys(Services.policies.getActivePolicies() || {}),
  app: Services.appinfo.name + " " + Services.appinfo.version,
};
"""


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    binary = sys.argv[1]
    prefs = expected_prefs()
    policies = json.loads((ROOT / "settings/policies.json").read_text())["policies"]

    with temp_profile() as profile:
        # Sem isto o Marionette aplica suas próprias prefs "recomendadas" para automação
        # (que desligam telemetria, safebrowsing etc.) e mascararia o resultado.
        Path(profile, "user.js").write_text('user_pref("remote.prefs.recommended", false);\n')
        proc = start(binary, profile, "--marionette", "-remote-allow-system-access")
        try:
            m = Marionette(PORT)
            m.send("WebDriver:NewSession", {})
            m.send("Marionette:SetContext", {"value": "chrome"})
            got = m.send("WebDriver:ExecuteScript", {"script": CHROME_SCRIPT, "args": [prefs]})["value"]
        finally:
            stop(proc)

    failures = []
    actual = {p["name"]: p for p in got["prefs"]}
    for p in prefs:
        a = actual[p["name"]]
        if a["value"] != p["value"]:
            failures.append(f'pref {p["name"]}: esperado {p["value"]!r}, obtido {a["value"]!r}')
        if p["locked"] and not a["locked"]:
            failures.append(f'pref {p["name"]}: deveria estar travada')

    if got["policyStatus"] != got["policyActive"]:
        failures.append("políticas não estão ativas (policies.json não foi carregado)")
    missing = sorted(set(policies) - set(got["activePolicies"]))
    if missing:
        failures.append(f"políticas rejeitadas/ignoradas: {', '.join(missing)}")

    print(f'{got["app"]}: {len(prefs)} prefs e {len(policies)} políticas conferidas')
    if failures:
        print("\n".join("FALHA: " + f for f in failures))
        sys.exit(1)
    print("OK")


if __name__ == "__main__":
    main()
