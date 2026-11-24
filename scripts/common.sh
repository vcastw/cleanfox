# Variáveis e funções compartilhadas. Use com: source "$(dirname "$0")/common.sh"
# shellcheck shell=bash disable=SC2034
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${CLEANFOX_BUILD_DIR:-$ROOT/build}"
SRC_DIR="$BUILD_DIR/src"
DIST_DIR="${CLEANFOX_DIST_DIR:-$ROOT/dist}"
ARCHIVE="https://archive.mozilla.org/pub/firefox/releases"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merro:\033[0m %s\n' "$*" >&2; exit 1; }
need() { for c in "$@"; do command -v "$c" >/dev/null || die "comando necessário não encontrado: $c"; done; }

# Plataforma alvo: linux | windows | macos | android (padrão: a do sistema atual).
host_target() {
  case "$(uname -s)" in
    Linux) echo linux ;;
    Darwin) echo macos ;;
    MINGW* | MSYS* | CYGWIN*) echo windows ;;
    *) die "sistema não suportado: $(uname -s)" ;;
  esac
}
TARGET="${CLEANFOX_TARGET:-$(host_target)}"
case "$TARGET" in
  linux | windows | macos | android) ;;
  *) die "CLEANFOX_TARGET inválido: $TARGET (use linux, windows, macos ou android)" ;;
esac
export CLEANFOX_TARGET="$TARGET"

# Desktop usa o Firefox ESR (arquivo `version`). O Android não tem ESR: usa a versão
# estável atual (arquivo `version-android`). Cada alvo tem sua própria árvore de fontes.
if [ "$TARGET" = android ]; then
  VERSION_FILE="$ROOT/version-android"
  SRC_DIR="$BUILD_DIR/src-android"
else
  VERSION_FILE="$ROOT/version"
fi

# Resolve o arquivo de versão para uma versão concreta do Firefox
# ("esr-latest" -> "153.7.0esr"; "release-latest" -> "160.0.1"; versão fixa -> ela mesma).
resolve_version() {
  local v key=""
  v="$(tr -d '[:space:]' < "$VERSION_FILE")"
  case "$v" in
    esr-latest) key=FIREFOX_ESR ;;
    release-latest) key=LATEST_FIREFOX_VERSION ;;
  esac
  if [ -n "$key" ]; then
    need curl python3
    v="$(curl -fsSL https://product-details.mozilla.org/1.0/firefox_versions.json \
      | python3 -c 'import json, sys; print(json.load(sys.stdin)[sys.argv[1]])' "$key")"
  fi
  [[ "$v" =~ ^[0-9]+(\.[0-9]+)+(esr)?$ ]] || die "versão inválida em $VERSION_FILE: '$v'"
  printf '%s\n' "$v"
}

# SHA portátil (macOS não tem sha256sum/sha512sum por padrão).
sha() { # sha <256|512> <arquivo> -> hash
  if command -v "sha${1}sum" >/dev/null; then
    "sha${1}sum" "$2" | cut -d' ' -f1
  else
    shasum -a "$1" "$2" | cut -d' ' -f1
  fi
}
