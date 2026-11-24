#!/usr/bin/env bash
# Verificações estáticas rápidas (rodam no CI a cada push).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== policies.json é JSON válido"
jq -e '.policies | type == "object"' settings/policies.json >/dev/null

echo "== cleanfox.js: formato das prefs e duplicadas"
# Só comentários //, linhas vazias e pref("nome", literal[, locked]); — é o que o
# pré-processador de prefs do Firefox aceita sem surpresas.
bad="$(grep -vE '^(//.*)?$' settings/cleanfox.js \
  | grep -vE "^pref\\(\"[A-Za-z0-9_.-]+\", (\"[^\"]*\"|'[^']*'|true|false|-?[0-9]+)(, locked)?\\);\$" || true)"
[ -z "$bad" ] || { echo "linhas fora do formato:"; echo "$bad"; exit 1; }
dups="$(grep -oE '^pref\("[^"]+"' settings/cleanfox.js | cut -d'"' -f2 | sort | uniq -d)"
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

echo "== mozconfig: sintaxe shell"
bash -n mozconfig

echo "== shellcheck"
shellcheck -x scripts/*.sh tests/*.sh

echo "== Python dos testes: sintaxe"
python3 -m py_compile tests/*.py tools/*.py

echo "== Release: só artefatos finais"
# O APK antes da assinatura tem os mesmos nomes de arquivo do assinado; não pode casar com
# o padrão que o job de release baixa.
grep -q 'pattern: cleanfox-\*' .github/workflows/build.yml \
  || { echo "ERRO: o job de release precisa baixar só pattern: cleanfox-*"; exit 1; }
if grep -nE 'name: cleanfox-.*unsigned' .github/workflows/build.yml; then
  echo "ERRO: artefato não assinado com nome que casa com cleanfox-*"; exit 1
fi

echo "== Empacotamento (pacotes falsos)"
tests/test-package.sh

echo "OK"
