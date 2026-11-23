# Variáveis e funções compartilhadas. Use com: source "$(dirname "$0")/common.sh"
# shellcheck shell=bash disable=SC2034
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${CLEANFOX_BUILD_DIR:-$ROOT/build}"
SRC_DIR="$BUILD_DIR/src"
DIST_DIR="$ROOT/dist"
ARCHIVE="https://archive.mozilla.org/pub/firefox/releases"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merro:\033[0m %s\n' "$*" >&2; exit 1; }
need() { for c in "$@"; do command -v "$c" >/dev/null || die "comando necessário não encontrado: $c"; done; }

# Resolve o conteúdo do arquivo `version` para uma versão concreta do Firefox ESR
# (ex.: "esr-latest" -> "140.5.0esr"; "140.5.0esr" -> "140.5.0esr").
resolve_version() {
  local v
  v="$(tr -d '[:space:]' < "$ROOT/version")"
  if [ "$v" = "esr-latest" ]; then
    need curl jq
    v="$(curl -fsSL https://product-details.mozilla.org/1.0/firefox_versions.json | jq -er .FIREFOX_ESR)"
  fi
  [[ "$v" =~ ^[0-9]+(\.[0-9]+)+esr$ ]] || die "versão inválida em ./version: '$v' (esperado algo como 140.5.0esr ou esr-latest)"
  printf '%s\n' "$v"
}
