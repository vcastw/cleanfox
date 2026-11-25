#!/usr/bin/env bash
# Testa scripts/package.sh com pacotes falsos (sem compilar nada).
# Regressões do Windows: o .zip era copiado mesmo faltando o instalador; o instalador era
# procurado em dist/install/sea (fica em dist/); o xpt_artifacts.zip podia passar pelo navegador.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export COLDFOX_BUILD_DIR="$tmp/build" COLDFOX_DIST_DIR="$tmp/dist" COLDFOX_TARGET=windows COLDFOX_ARCH=x86_64
dist="$COLDFOX_BUILD_DIR/src/obj-coldfox/dist"
mkdir -p "$dist"
echo 153.7.0esr > "$COLDFOX_BUILD_DIR/src/.coldfox-version"
echo zip > "$dist/coldfox-153.7.0.en-US.win64.zip"
# Isca: vem antes na ordem alfabética e não é o navegador.
echo xpt > "$dist/coldfox-153.7.0.en-US.win64.xpt_artifacts.zip"

if "$ROOT/scripts/package.sh" >/dev/null 2>&1; then
  echo "FALHA: package.sh aceitou Windows sem instalador"; exit 1
fi
[ ! -e "$COLDFOX_DIST_DIR/coldfox-153.7.0-windows-x86_64.zip" ] \
  || { echo "FALHA: copiou o .zip antes de achar o instalador"; exit 1; }

echo exe > "$dist/coldfox-153.7.0.en-US.win64.installer.exe"
"$ROOT/scripts/package.sh" >/dev/null
for f in coldfox-153.7.0-windows-x86_64.zip coldfox-153.7.0-windows-x86_64-setup.exe; do
  if [ ! -f "$COLDFOX_DIST_DIR/$f" ] || [ ! -f "$COLDFOX_DIST_DIR/$f.sha256" ]; then
    echo "FALHA: faltou $f ou o .sha256"; exit 1
  fi
done
grep -qx zip "$COLDFOX_DIST_DIR/coldfox-153.7.0-windows-x86_64.zip" \
  || { echo "FALHA: recolheu o xpt_artifacts.zip no lugar do navegador"; exit 1; }
echo "ok: package.sh (windows)"

# Linux: policies.json obrigatório, pingsender proibido, Vendor=ColdFox.
export COLDFOX_TARGET=linux
rm -rf "$COLDFOX_DIST_DIR"
lin="$tmp/lin/coldfox"
mkpkg() { # mkpkg <vendor> [extra]
  rm -rf "$tmp/lin" "$dist"/coldfox-*.tar.xz; mkdir -p "$lin/distribution"
  echo '{}' > "$lin/distribution/policies.json"
  printf '[App]\nVendor=%s\n' "$1" > "$lin/application.ini"
  [ -z "${2:-}" ] || echo x > "$lin/$2"
  tar -cJf "$dist/coldfox-153.7.0.en-US.linux-x86_64.tar.xz" -C "$tmp/lin" coldfox
}
mkpkg ColdFox pingsender
! "$ROOT/scripts/package.sh" >/dev/null 2>&1 || { echo "FALHA: package.sh aceitou Linux com pingsender"; exit 1; }
mkpkg Mozilla
! "$ROOT/scripts/package.sh" >/dev/null 2>&1 || { echo "FALHA: package.sh aceitou Vendor=Mozilla"; exit 1; }
mkpkg ColdFox
"$ROOT/scripts/package.sh" >/dev/null
[ -f "$COLDFOX_DIST_DIR/coldfox-153.7.0-linux-x86_64.tar.xz.sha256" ] || { echo "FALHA: faltou o pacote Linux"; exit 1; }
echo "ok: package.sh (linux)"
