#!/usr/bin/env bash
# Aplica branding, configuração, patches e mozconfig do CleanFox sobre a árvore de fontes.
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"
need patch

[ -f "$SRC_DIR/.cleanfox-version" ] || die "fonte não encontrada em $SRC_DIR (rode scripts/fetch.sh)"
[ ! -f "$SRC_DIR/.cleanfox-prepared" ] || die "fonte já preparada; rode scripts/fetch.sh para recomeçar de uma árvore limpa"

# Remove comentários e linhas vazias: os arquivos de prefs do Firefox passam por um
# pré-processador, e assim só entram neles linhas pref(...) simples.
prefs_block() {
  echo
  echo "// ---- CleanFox (gerado de settings/cleanfox.js) ----"
  grep -E '^pref\(' "$ROOT/settings/cleanfox.js"
}

apply_patches() {
  local dir="$1" p
  shopt -s nullglob
  for p in "$dir"/*.patch; do
    log "  $(basename "$p")"
    patch -d "$SRC_DIR" -p1 --forward --no-backup-if-mismatch < "$p" || die "falha ao aplicar $(basename "$p")"
  done
}

if [ "$TARGET" = android ]; then
  "$ROOT/scripts/prepare-android.sh"
  log "Prefs (GeckoView)"
  prefs_block >> "$SRC_DIR/mobile/android/app/geckoview-prefs.js"
  log "Patches"
  apply_patches "$ROOT/patches/android"
else
  log "Branding"
  # Base: o branding "unofficial" do próprio Firefox (ícones genéricos, sem marcas registradas).
  rm -rf "$SRC_DIR/browser/branding/cleanfox"
  cp -r "$SRC_DIR/browser/branding/unofficial" "$SRC_DIR/browser/branding/cleanfox"
  cp -r "$ROOT/branding/." "$SRC_DIR/browser/branding/cleanfox/"

  log "Prefs e políticas"
  prefs_block >> "$SRC_DIR/browser/app/profile/firefox.js"
  cp "$ROOT/settings/policies.json" "$SRC_DIR/browser/app/distribution/policies.json"

  log "Patches"
  apply_patches "$ROOT/patches"
fi

log "mozconfig"
cp "$ROOT/mozconfig" "$SRC_DIR/mozconfig"
touch "$SRC_DIR/.cleanfox-prepared"
