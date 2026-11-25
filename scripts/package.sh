#!/usr/bin/env bash
# Recolhe os pacotes gerados pela compilação em dist/, com nome padronizado e SHA-256.
#   linux   -> coldfox-<versão>-linux-<arq>.tar.xz
#   windows -> coldfox-<versão>-windows-<arq>.zip e -setup.exe
#   macos   -> coldfox-<versão>-macos-<arq>.dmg
#   android -> coldfox-<versão>-android-<abi>.apk
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

VERSION="$(cat "$SRC_DIR/.coldfox-version")"
VERSION="${VERSION%esr}"
OBJ="$SRC_DIR/obj-coldfox"
ARCH="${COLDFOX_ARCH:-$(uname -m)}"
mkdir -p "$DIST_DIR"
shopt -s nullglob

collect() { # collect <origem> <nome-final>
  [ -f "$1" ] || die "arquivo esperado não encontrado: $1"
  cp "$1" "$DIST_DIR/$2"
  log "dist/$2"
}
first() { # first <glob...> -> primeiro arquivo existente
  local f
  for f in "$@"; do [ -f "$f" ] && { printf '%s\n' "$f"; return; }; done
  log "conteúdo de $OBJ/dist:"
  find "$OBJ/dist" -maxdepth 3 \( -name '*.exe' -o -name '*.zip' -o -name '*.dmg' -o -name '*.tar.*' \) >&2 || true
  die "nenhum pacote encontrado (rode scripts/build.sh)."
}

case "$TARGET" in
  linux)
    pkg="$(first "$OBJ"/dist/coldfox-*.tar.xz "$OBJ"/dist/coldfox-*.tar.bz2)"
    # Lista antes de filtrar: com pipefail, `tar | grep -q` falha por SIGPIPE quando o grep acha cedo.
    listing="$(tar -tf "$pkg")"
    grep -qx 'coldfox/distribution/policies.json' <<< "$listing" \
      || die "o pacote não contém distribution/policies.json (patch 0001 não aplicado?)"
    ! grep -qx 'coldfox/pingsender' <<< "$listing" \
      || die "o pacote contém o pingsender (patch 0002 não aplicado?)"
    tar -xOf "$pkg" coldfox/application.ini | grep -qx 'Vendor=ColdFox' \
      || die "application.ini não diz Vendor=ColdFox (MOZ_APP_VENDOR no mozconfig)"
    collect "$pkg" "coldfox-$VERSION-linux-$ARCH.tar.${pkg##*.}"
    ;;
  windows)
    # Atribuição separada: `die` dentro de "$(...)" não encerraria o script.
    # dist/ também tem coldfox-*.xpt_artifacts.zip, que vem antes na ordem alfabética.
    zips=()
    for z in "$OBJ"/dist/coldfox-*.zip; do [[ "$z" == *_artifacts.zip ]] || zips+=("$z"); done
    zip="$(first "${zips[@]}")"
    setup="$(first "$OBJ"/dist/coldfox-*.installer.exe)"
    collect "$zip" "coldfox-$VERSION-windows-$ARCH.zip"
    collect "$setup" "coldfox-$VERSION-windows-$ARCH-setup.exe"
    ;;
  macos)
    dmg="$(first "$OBJ"/dist/coldfox-*.dmg)"
    collect "$dmg" "coldfox-$VERSION-macos-$ARCH.dmg"
    ;;
  android)
    apks=("$OBJ"/gradle/build/mobile/android/fenix/app/outputs/apk/release/*.apk)
    [ "${#apks[@]}" -ge 1 ] || die "nenhum APK encontrado (rode scripts/build.sh)"
    for apk in "${apks[@]}"; do
      abi="$(basename "$apk" .apk | sed -E 's/^app-//; s/-release.*$//')"
      collect "$apk" "coldfox-$VERSION-android-$abi.apk"
    done
    ;;
esac

for f in "$DIST_DIR"/coldfox-"$VERSION"-*; do
  case "$f" in
    *.sha256) ;;
    *) printf '%s  %s\n' "$(sha 256 "$f")" "$(basename "$f")" > "$f.sha256" ;;
  esac
done
