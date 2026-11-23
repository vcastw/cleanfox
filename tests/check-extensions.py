#!/usr/bin/env python3
"""Teste de runtime das extensões de fábrica: sobe o navegador (headless, perfil novo,
COM rede) e espera cada extensão de ExtensionSettings ser baixada e instalada.

Confere que cada uma está instalada, ativa, assinada pela Mozilla e liberada em janela
privativa. Uso: tests/check-extensions.py /caminho/para/firefox-ou-cleanfox

Atrás de um proxy que intercepta TLS, aponte CLEANFOX_TEST_EXTRA_CA para a CA dele: ela é
confiada só no perfil temporário do teste, que também sai do modo estrito de fixação de
certificados (requer `certutil`, do pacote NSS tools).
"""
import os
import importlib.util
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("runtime", ROOT / "tests/check-runtime.py")
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)

SCRIPT = """
const [ids, done] = [arguments[0], arguments[arguments.length - 1]];
const { AddonManager } = ChromeUtils.importESModule("resource://gre/modules/AddonManager.sys.mjs");
const { ExtensionPermissions } = ChromeUtils.importESModule("resource://gre/modules/ExtensionPermissions.sys.mjs");
(async () => {
  const out = {};
  for (const id of ids) {
    const a = await AddonManager.getAddonByID(id);
    if (!a) { out[id] = null; continue; }
    const perms = await ExtensionPermissions.get(id);
    out[id] = {
      name: a.name, version: a.version, active: a.isActive,
      signed: a.signedState >= AddonManager.SIGNEDSTATE_SIGNED,
      private: perms.permissions.includes("internal:privateBrowsingAllowed"),
    };
  }
  done(out);
})().catch(e => done({ error: String(e) }));
"""


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    settings = json.loads((ROOT / "settings/policies.json").read_text())["policies"]["ExtensionSettings"]
    ids = [i for i, s in settings.items() if s.get("installation_mode") in ("normal_installed", "force_installed")]

    with tempfile.TemporaryDirectory() as profile:
        Path(profile, "user.js").write_text('user_pref("remote.prefs.recommended", false);\n')
        extra_ca = os.environ.get("CLEANFOX_TEST_EXTRA_CA")
        if extra_ca:
            db = f"sql:{profile}"
            subprocess.run(["certutil", "-N", "--empty-password", "-d", db], check=True)
            subprocess.run(["certutil", "-A", "-n", "test-extra-ca", "-t", "C,,", "-i", extra_ca, "-d", db], check=True)
            # O CleanFox fixa os certificados de domínios da Mozilla no modo estrito (2), que
            # recusa justamente uma CA de interceptação. Só neste perfil de teste: modo 1.
            with open(Path(profile, "user.js"), "a") as f:
                f.write('user_pref("security.cert_pinning.enforcement_level", 1);\n')
        proc = subprocess.Popen(
            [sys.argv[1], "--headless", "--no-remote", "--marionette", "-remote-allow-system-access", "--profile", profile],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        try:
            m = runtime.Marionette(runtime.PORT)
            m.send("WebDriver:NewSession", {})
            m.send("Marionette:SetContext", {"value": "chrome"})
            m.send("WebDriver:SetTimeouts", {"script": 30000})
            deadline = time.time() + 180
            while True:
                got = m.send("WebDriver:ExecuteAsyncScript", {"script": SCRIPT, "args": [ids]})["value"]
                if "error" in got:
                    sys.exit("erro no navegador: " + got["error"])
                ready = all(got[i] and got[i]["active"] for i in ids)
                if ready or time.time() > deadline:
                    break
                time.sleep(3)
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=20)
            except subprocess.TimeoutExpired:
                proc.kill()

    failures = []
    for i in ids:
        a = got[i]
        if not a:
            failures.append(f"{i}: não foi instalada")
            continue
        print(f'{a["name"]} {a["version"]}: ativa={a["active"]} assinada={a["signed"]} privativa={a["private"]}')
        for key in ("active", "signed", "private"):
            want = key != "private" or settings[i].get("private_browsing", False)
            if a[key] != want:
                failures.append(f'{a["name"]}: {key} = {a[key]}, esperado {want}')
    if failures:
        print("\n".join("FALHA: " + f for f in failures))
        sys.exit(1)
    print("OK")


if __name__ == "__main__":
    main()
