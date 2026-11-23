#!/usr/bin/env bash
# Baixa o código-fonte oficial do Firefox (ESR no desktop, estável no Android), confere o SHA-512 e extrai em build/src.
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"
need curl tar xz

VERSION="$(resolve_version)"
TARBALL="firefox-$VERSION.source.tar.xz"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR" || exit 1

if [ ! -f "$TARBALL" ]; then
  log "Baixando $TARBALL"
  curl -fL --retry 3 -o "$TARBALL.part" "$ARCHIVE/$VERSION/source/$TARBALL"
  mv "$TARBALL.part" "$TARBALL"
fi

log "Conferindo SHA-512"
curl -fsSL -o SHA512SUMS "$ARCHIVE/$VERSION/SHA512SUMS"
expected="$(awk -v f="source/$TARBALL" '$2 == f { print $1 }' SHA512SUMS)"
[ -n "$expected" ] || die "$TARBALL não consta no SHA512SUMS"
actual="$(sha 512 "$TARBALL")"
[ "$expected" = "$actual" ] || die "SHA-512 não confere para $TARBALL (apague o arquivo e baixe de novo)"

# Assinatura GPG da Mozilla sobre o SHA512SUMS. Só é conferida se a chave de release
# da Mozilla já estiver no seu chaveiro (importe-a de uma fonte em que você confia).
if command -v gpg >/dev/null && curl -fsSL -o SHA512SUMS.asc "$ARCHIVE/$VERSION/SHA512SUMS.asc"; then
  if gpg --verify SHA512SUMS.asc SHA512SUMS 2>/dev/null; then
    log "Assinatura GPG válida"
  else
    log "AVISO: assinatura GPG não verificada (chave da Mozilla ausente do chaveiro?)"
  fi
fi

log "Extraindo em $SRC_DIR"
rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR"
tar -xJf "$TARBALL" -C "$SRC_DIR" --strip-components=1
printf '%s\n' "$VERSION" > "$SRC_DIR/.cleanfox-version"
log "Fonte do Firefox $VERSION pronta"
