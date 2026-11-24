#!/usr/bin/env bash
# Testa scripts/package.sh com pacotes falsos (sem compilar nada).
# Regressões do Windows: o .zip era copiado mesmo faltando o instalador; o instalador era
# procurado em dist/install/sea (fica em dist/); o xpt_artifacts.zip podia passar pelo navegador.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export CLEANFOX_BUILD_DIR="$tmp/build" CLEANFOX_DIST_DIR="$tmp/dist" CLEANFOX_TARGET=windows CLEANFOX_ARCH=x86_64
dist="$CLEANFOX_BUILD_DIR/src/obj-cleanfox/dist"
mkdir -p "$dist"
echo 153.7.0esr > "$CLEANFOX_BUILD_DIR/src/.cleanfox-version"
echo zip > "$dist/cleanfox-153.7.0.en-US.win64.zip"
# Isca: vem antes na ordem alfabética e não é o navegador.
echo xpt > "$dist/cleanfox-153.7.0.en-US.win64.xpt_artifacts.zip"

if "$ROOT/scripts/package.sh" >/dev/null 2>&1; then
  echo "FALHA: package.sh aceitou Windows sem instalador"; exit 1
fi
[ ! -e "$CLEANFOX_DIST_DIR/cleanfox-153.7.0-windows-x86_64.zip" ] \
  || { echo "FALHA: copiou o .zip antes de achar o instalador"; exit 1; }

echo exe > "$dist/cleanfox-153.7.0.en-US.win64.installer.exe"
"$ROOT/scripts/package.sh" >/dev/null
for f in cleanfox-153.7.0-windows-x86_64.zip cleanfox-153.7.0-windows-x86_64-setup.exe; do
  if [ ! -f "$CLEANFOX_DIST_DIR/$f" ] || [ ! -f "$CLEANFOX_DIST_DIR/$f.sha256" ]; then
    echo "FALHA: faltou $f ou o .sha256"; exit 1
  fi
done
grep -qx zip "$CLEANFOX_DIST_DIR/cleanfox-153.7.0-windows-x86_64.zip" \
  || { echo "FALHA: recolheu o xpt_artifacts.zip no lugar do navegador"; exit 1; }
echo "ok: package.sh (windows)"
