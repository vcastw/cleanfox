#!/usr/bin/env bash
# Instala a configuração do CleanFox num Firefox desktop já instalado (Linux, Windows
# ou macOS), sem compilar nada. Passe a pasta da instalação:
#   Linux:   scripts/apply-config.sh /usr/lib/firefox
#   macOS:   scripts/apply-config.sh /Applications/Firefox.app
#   Windows: scripts/apply-config.sh "/c/Program Files/Mozilla Firefox"   (Git Bash)
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

APP_DIR="${1:-}"
[ -n "$APP_DIR" ] || die "uso: $0 <pasta-da-instalação>"
# No macOS os recursos ficam dentro do pacote .app
[ ! -d "$APP_DIR/Contents/Resources" ] || APP_DIR="$APP_DIR/Contents/Resources"
[ -f "$APP_DIR/application.ini" ] || die "$APP_DIR não parece uma instalação do Firefox (application.ini ausente)"

mkdir -p "$APP_DIR/browser/defaults/preferences" "$APP_DIR/distribution"
cp "$ROOT/settings/cleanfox.js" "$APP_DIR/browser/defaults/preferences/cleanfox.js"
cp "$ROOT/settings/policies.json" "$APP_DIR/distribution/policies.json"
log "Configuração instalada em $APP_DIR (reinicie o navegador)"
