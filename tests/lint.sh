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
  | grep -vE '^pref\("[A-Za-z0-9_.-]+", ("[^"]*"|true|false|-?[0-9]+)(, locked)?\);$' || true)"
[ -z "$bad" ] || { echo "linhas fora do formato:"; echo "$bad"; exit 1; }
dups="$(grep -oE '^pref\("[^"]+"' settings/cleanfox.js | cut -d'"' -f2 | sort | uniq -d)"
[ -z "$dups" ] || { echo "prefs duplicadas:"; echo "$dups"; exit 1; }

echo "== patches: cabeçalhos de diff presentes"
for p in patches/*.patch patches/android/*.patch; do
  [ -e "$p" ] || continue
  if ! grep -q '^--- a/' "$p" || ! grep -q '^+++ b/' "$p"; then echo "patch malformado: $p"; exit 1; fi
done

echo "== mozconfig: sintaxe shell"
bash -n mozconfig

echo "== shellcheck"
shellcheck -x scripts/*.sh tests/*.sh

echo "OK"
