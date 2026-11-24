#!/usr/bin/env bash
# Compila o CleanFox para $CLEANFOX_TARGET. Desktop: ~40 GB de disco, 16 GB de RAM
# (8 GB com CLEANFOX_FAST_BUILD=1) e de 1 a várias horas. Compile cada plataforma
# desktop no próprio sistema; Android compila em Linux ou macOS.
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

[ -f "$SRC_DIR/.cleanfox-prepared" ] || die "fonte não preparada (rode scripts/fetch.sh e scripts/prepare.sh)"
cd "$SRC_DIR" || exit 1
export MOZCONFIG="$SRC_DIR/mozconfig"
export MOZBUILD_STATE_PATH="${MOZBUILD_STATE_PATH:-$BUILD_DIR/mozbuild}"

if [ -z "${CLEANFOX_SKIP_BOOTSTRAP:-}" ]; then
  log "Instalando toolchain (mach bootstrap)"
  if [ "$TARGET" = android ]; then
    ./mach --no-interactive bootstrap --application-choice mobile_android
  else
    ./mach --no-interactive bootstrap --application-choice browser
  fi
fi

log "Compilando ($TARGET)"
./mach build

log "Empacotando"
if [ "$TARGET" = android ]; then
  # APK assinado com a chave de debug local; para distribuir, reassine com a sua chave
  # (veja "Android" no README).
  ./mach gradle fenix:assembleRelease
else
  # No Windows, além do .zip, gera o instalador em dist/<pacote>.installer.exe.
  ./mach package
fi
