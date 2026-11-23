#!/usr/bin/env bash
# Aplica branding, patches e mozconfig do CleanFox sobre build/src.
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"
need patch

[ -d "$SRC_DIR/browser/branding/unofficial" ] || die "fonte não encontrada em $SRC_DIR (rode scripts/fetch.sh)"

log "Branding"
# Base: o branding "unofficial" do próprio Firefox (ícones genéricos, sem marcas registradas).
rm -rf "$SRC_DIR/browser/branding/cleanfox"
cp -r "$SRC_DIR/browser/branding/unofficial" "$SRC_DIR/browser/branding/cleanfox"
cp -r "$ROOT/branding/." "$SRC_DIR/browser/branding/cleanfox/"

log "Patches"
shopt -s nullglob
for p in "$ROOT"/patches/*.patch; do
  log "  $(basename "$p")"
  patch -d "$SRC_DIR" -p1 --forward --no-backup-if-mismatch < "$p" || die "falha ao aplicar $(basename "$p")"
done

log "mozconfig"
cp "$ROOT/mozconfig" "$SRC_DIR/mozconfig"
