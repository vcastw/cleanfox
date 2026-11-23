#!/usr/bin/env bash
# Verificações estáticas rápidas (rodam no CI a cada push).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== policies.json é JSON válido"
jq -e '.policies | type == "object"' settings/distribution/policies.json >/dev/null

echo "== cleanfox.cfg: sintaxe JS e prefs duplicadas"
tmp="$(mktemp --suffix=.js)"; trap 'rm -f "$tmp"' EXIT
cp settings/cleanfox.cfg "$tmp"
node --check "$tmp"
dups="$(grep -oE '^(lock|default)?[pP]ref\("[^"]+"' settings/cleanfox.cfg | cut -d'"' -f2 | sort | uniq -d)"
[ -z "$dups" ] || { echo "prefs duplicadas:"; echo "$dups"; exit 1; }

echo "== cleanfox.cfg: só lockPref/defaultPref com literais"
bad="$(grep -vE '^\s*(//.*)?$' settings/cleanfox.cfg \
  | grep -vE '^(lockPref|defaultPref)\("[A-Za-z0-9_.-]+", ("[^"]*"|true|false|-?[0-9]+)\);$' || true)"
[ -z "$bad" ] || { echo "linhas fora do formato:"; echo "$bad"; exit 1; }

echo "== mozconfig: sintaxe shell"
bash -n mozconfig

echo "== shellcheck"
shellcheck -x scripts/*.sh tests/*.sh

echo "OK"
