#!/usr/bin/env bash
# Pega o pacote gerado pelo `mach package`, injeta a configuração do CleanFox
# (cleanfox.cfg, autoconfig.js, policies.json) e gera dist/cleanfox-<versão>-<plataforma>.tar.xz
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"
need tar xz sha256sum

shopt -s nullglob
pkgs=("$SRC_DIR"/obj-cleanfox/dist/cleanfox-*.tar.xz "$SRC_DIR"/obj-cleanfox/dist/cleanfox-*.tar.bz2)
[ "${#pkgs[@]}" -ge 1 ] || die "nenhum pacote em obj-cleanfox/dist (rode scripts/build.sh)"
pkg="${pkgs[0]}"

VERSION="$(cat "$BUILD_DIR/.version")"
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
OUT="cleanfox-${VERSION%esr}-$PLATFORM.tar.xz"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
log "Extraindo $(basename "$pkg")"
tar -xf "$pkg" -C "$stage"
[ -x "$stage/cleanfox/cleanfox" ] || die "layout inesperado do pacote (esperado cleanfox/cleanfox)"

log "Injetando configuração"
"$ROOT/scripts/apply-config.sh" "$stage/cleanfox"

mkdir -p "$DIST_DIR"
log "Gerando dist/$OUT"
tar -C "$stage" -cJf "$DIST_DIR/$OUT" cleanfox
(cd "$DIST_DIR" && sha256sum "$OUT" > "$OUT.sha256")
log "Pronto: $DIST_DIR/$OUT"
