#!/usr/bin/env bash
# Verificações estáticas rápidas (rodam no CI a cada push).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== policies.json é JSON válido"
jq -e '.policies | type == "object"' settings/policies.json >/dev/null

echo "== coldfox.js: formato das prefs e duplicadas"
# Só comentários //, linhas vazias e pref("nome", literal[, locked]); — é o que o
# pré-processador de prefs do Firefox aceita sem surpresas.
bad="$(grep -vE '^(//.*)?$' settings/coldfox.js \
  | grep -vE "^pref\\(\"[A-Za-z0-9_.-]+\", (\"[^\"]*\"|'[^']*'|true|false|-?[0-9]+)(, locked)?\\);\$" || true)"
[ -z "$bad" ] || { echo "linhas fora do formato:"; echo "$bad"; exit 1; }
dups="$(grep -oE '^pref\("[^"]+"' settings/coldfox.js | cut -d'"' -f2 | sort | uniq -d)"
[ -z "$dups" ] || { echo "prefs duplicadas:"; echo "$dups"; exit 1; }

echo "== patches: cabeçalhos de diff presentes"
for p in patches/*.patch patches/android/*.patch; do
  [ -e "$p" ] || continue
  if ! grep -q '^--- a/' "$p" || ! grep -q '^+++ b/' "$p"; then echo "patch malformado: $p"; exit 1; fi
done

echo "== workflows: toda action fixada por SHA (tag é mutável)"
bad="$(grep -hnE '^\s*-?\s*uses:' .github/workflows/*.yml | grep -vE 'uses: [^@]+@[0-9a-f]{40}( |$)' || true)"
[ -z "$bad" ] || { echo "actions sem SHA fixo:"; echo "$bad"; exit 1; }

echo "== keys/: chave da Mozilla bate com a impressão digital fixada em fetch.sh"
fpr="$(sed -nE 's/^MOZILLA_KEY_FPR="([0-9A-F]{40})"$/\1/p' scripts/fetch.sh)"
[ -n "$fpr" ] || { echo "MOZILLA_KEY_FPR ausente em scripts/fetch.sh"; exit 1; }
gpg --batch --with-colons --import-options show-only --import keys/mozilla-release-key.asc 2>/dev/null \
  | awk -F: '/^pub/{p=1;next} p&&/^fpr/{print $10; exit}' | grep -qx "$fpr" \
  || { echo "keys/mozilla-release-key.asc não é a chave $fpr"; exit 1; }

echo "== allowed-hosts.txt: todo host tem motivo"
bad="$(grep -vE '^(#.*)?$' tests/allowed-hosts.txt | grep -vE '^[a-z0-9.-]+  [^ ].+$' || true)"
[ -z "$bad" ] || { echo "linhas sem motivo:"; echo "$bad"; exit 1; }

echo "== branding: telas secundárias com a marca do ColdFox"
# O branding "unofficial" do Firefox, usado de base, mostra "Nightly" e um globo na janela
# "Sobre", na nova aba, no instalador e nos ícones de documento e de navegação privativa.
for f in content/about-logo.png content/about-logo@2x.png content/about-logo.svg \
         content/about-logo-private.png content/about-logo-private@2x.png content/about.png \
         content/about-wordmark.svg content/firefox-wordmark.svg content/aboutDialog.css \
         VisualElements_70.png VisualElements_150.png PrivateBrowsing_70.png PrivateBrowsing_150.png \
         pbmode.ico document.ico document.icns wizHeader.bmp wizHeaderRTL.bmp wizWatermark.bmp; do
  [ -f "branding/$f" ] || { echo "falta branding/$f (rode tools/gen-branding.py)"; exit 1; }
done
grep -q '<title>ColdFox</title>' branding/content/about-wordmark.svg branding/content/firefox-wordmark.svg \
  || { echo "wordmarks sem o texto ColdFox"; exit 1; }

echo "== mozconfig: sintaxe shell"
bash -n mozconfig

echo "== shellcheck"
shellcheck -x scripts/*.sh tests/*.sh tools/*.sh

echo "== Python dos testes: sintaxe"
python3 -m py_compile tests/*.py tools/*.py

echo "== Release: só artefatos finais"
# O APK antes da assinatura tem os mesmos nomes de arquivo do assinado; não pode casar com
# o padrão que o job de release baixa.
grep -q 'pattern: coldfox-\*' .github/workflows/build.yml \
  || { echo "ERRO: o job de release precisa baixar só pattern: coldfox-*"; exit 1; }
if grep -nE 'name: coldfox-.*unsigned' .github/workflows/build.yml; then
  echo "ERRO: artefato não assinado com nome que casa com coldfox-*"; exit 1
fi

# Release sem a chave do Android não sai (falha fechado), e o job de release depende disso.
grep -q 'needs: \[release-check, ' .github/workflows/build.yml \
  || { echo "ERRO: o job de release precisa depender de release-check"; exit 1; }
grep -q "Android Debug" .github/workflows/build.yml \
  || { echo "ERRO: android-sign precisa reprovar chave de debug em release"; exit 1; }

# Entradas do disparo manual só por variável de ambiente, nunca dentro de um `run:`
# (texto interpolado no shell vira injeção de comando).
python3 - <<'PY'
import glob, sys, yaml
ruim = [f"{f}: job {j}: {st.get('name', st['run'][:40])}"
        for f in glob.glob(".github/workflows/*.yml")
        for j, job in yaml.safe_load(open(f))["jobs"].items()
        for st in job.get("steps", [])
        if "${{" in st.get("run", "") and ("inputs." in st["run"] or "github.event." in st["run"] or "github.ref_name" in st["run"])]
if ruim:
    sys.exit("ERRO: expressão controlável por quem dispara dentro de run: (use env:)\n" + "\n".join(ruim))
PY

echo "== Empacotamento, release e instalador (pacotes falsos)"
tests/test-package.sh
tests/test-release.sh

echo "OK"
