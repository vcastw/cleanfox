#!/usr/bin/env bash
# Compila o CleanFox. Precisa de ~40 GB de disco, 16 GB de RAM (8 GB com CLEANFOX_FAST_BUILD=1)
# e de 1 a várias horas, dependendo da máquina.
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

[ -f "$SRC_DIR/mozconfig" ] || die "fonte não preparada (rode scripts/fetch.sh e scripts/prepare.sh)"
cd "$SRC_DIR" || exit 1
export MOZCONFIG="$SRC_DIR/mozconfig"
export MOZBUILD_STATE_PATH="${MOZBUILD_STATE_PATH:-$BUILD_DIR/mozbuild}"

if [ -z "${CLEANFOX_SKIP_BOOTSTRAP:-}" ]; then
  log "Instalando toolchain (mach bootstrap)"
  ./mach --no-interactive bootstrap --application-choice browser
fi

log "Compilando"
./mach build

log "Empacotando"
./mach package
