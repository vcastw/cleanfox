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

# Integridade em duas etapas, falhando fechado:
#  1. SHA512SUMS assinado pela chave de release da Mozilla. A chave pública fica neste
#     repositório (keys/), com a impressão digital fixada abaixo: o servidor de download
#     não consegue trocar a raiz de confiança.
#  2. SHA-512 do tarball conferido contra o SHA512SUMS autenticado.
MOZILLA_KEY_FPR="14F26682D0916CDD81E37B6D61B7B526D98F0353"
need gpg gpgv

log "Conferindo assinatura da Mozilla"
curl -fsSL -o SHA512SUMS "$ARCHIVE/$VERSION/SHA512SUMS"
curl -fsSL -o SHA512SUMS.asc "$ARCHIVE/$VERSION/SHA512SUMS.asc"
keyring="$BUILD_DIR/mozilla-release-key.gpg"
gpg --batch --yes --dearmor -o "$keyring" "$ROOT/keys/mozilla-release-key.asc"
status="$(gpgv --status-fd 1 --keyring "$keyring" SHA512SUMS.asc SHA512SUMS 2>/dev/null || true)"
grep -q "^\[GNUPG:\] VALIDSIG .* $MOZILLA_KEY_FPR\$" <<< "$status" \
  || die "assinatura do SHA512SUMS inválida ou de outra chave (se a Mozilla trocou a chave, atualize keys/ conferindo a impressão digital por outro canal)"
log "Assinatura válida (chave $MOZILLA_KEY_FPR)"

log "Conferindo SHA-512"
expected="$(awk -v f="source/$TARBALL" '$2 == f { print $1 }' SHA512SUMS)"
[ -n "$expected" ] || die "$TARBALL não consta no SHA512SUMS"
actual="$(sha 512 "$TARBALL")"
[ "$expected" = "$actual" ] || die "SHA-512 não confere para $TARBALL (apague o arquivo e baixe de novo)"

log "Extraindo em $SRC_DIR"
rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR"
tar -xJf "$TARBALL" -C "$SRC_DIR" --strip-components=1
printf '%s\n' "$VERSION" > "$SRC_DIR/.cleanfox-version"
log "Fonte do Firefox $VERSION pronta"
