#!/usr/bin/env bash
# Instala a configuração do CleanFox em um diretório de instalação do CleanFox ou do
# Firefox (a pasta que contém o executável). Útil para testar as prefs sem compilar:
#   scripts/apply-config.sh /caminho/para/firefox
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

APP_DIR="${1:-}"
[ -n "$APP_DIR" ] || die "uso: $0 <diretório-da-instalação>"
[ -f "$APP_DIR/application.ini" ] || die "$APP_DIR não parece uma instalação (application.ini ausente)"

install -D -m 644 "$ROOT/settings/cleanfox.cfg" "$APP_DIR/cleanfox.cfg"
install -D -m 644 "$ROOT/settings/defaults/pref/autoconfig.js" "$APP_DIR/defaults/pref/autoconfig.js"
install -D -m 644 "$ROOT/settings/distribution/policies.json" "$APP_DIR/distribution/policies.json"
log "Configuração instalada em $APP_DIR"
