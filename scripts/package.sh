#!/usr/bin/env bash
# Recolhe os pacotes gerados pela compilação em dist/, com nome padronizado e SHA-256.
#   linux   -> cleanfox-<versão>-linux-<arq>.tar.xz
#   windows -> cleanfox-<versão>-windows-<arq>.zip e -setup.exe
#   macos   -> cleanfox-<versão>-macos-<arq>.dmg
#   android -> cleanfox-<versão>-android-<abi>.apk
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"

VERSION="$(cat "$SRC_DIR/.cleanfox-version")"
VERSION="${VERSION%esr}"
OBJ="$SRC_DIR/obj-cleanfox"
ARCH="${CLEANFOX_ARCH:-$(uname -m)}"
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
    pkg="$(first "$OBJ"/dist/cleanfox-*.tar.xz "$OBJ"/dist/cleanfox-*.tar.bz2)"
    # Lista antes de filtrar: com pipefail, `tar | grep -q` falha por SIGPIPE quando o grep acha cedo.
    listing="$(tar -tf "$pkg")"
    grep -qx 'cleanfox/distribution/policies.json' <<< "$listing" \
      || die "o pacote não contém distribution/policies.json (patch 0001 não aplicado?)"
    collect "$pkg" "cleanfox-$VERSION-linux-$ARCH.tar.${pkg##*.}"
    ;;
  windows)
    # Atribuição separada: `die` dentro de "$(...)" não encerraria o script.
    zip="$(first "$OBJ"/dist/cleanfox-*.zip)"
    setup="$(first "$OBJ"/dist/install/sea/*.installer.exe "$OBJ"/dist/install/sea/*.exe)"
    collect "$zip" "cleanfox-$VERSION-windows-$ARCH.zip"
    collect "$setup" "cleanfox-$VERSION-windows-$ARCH-setup.exe"
    ;;
  macos)
    dmg="$(first "$OBJ"/dist/cleanfox-*.dmg)"
    collect "$dmg" "cleanfox-$VERSION-macos-$ARCH.dmg"
    ;;
  android)
    apks=("$OBJ"/gradle/build/mobile/android/fenix/app/outputs/apk/release/*.apk)
    [ "${#apks[@]}" -ge 1 ] || die "nenhum APK encontrado (rode scripts/build.sh)"
    for apk in "${apks[@]}"; do
      abi="$(basename "$apk" .apk | sed -E 's/^app-//; s/-release.*$//')"
      collect "$apk" "cleanfox-$VERSION-android-$abi.apk"
    done
    ;;
esac

for f in "$DIST_DIR"/cleanfox-"$VERSION"-*; do
  case "$f" in
    *.sha256) ;;
    *) printf '%s  %s\n' "$(sha 256 "$f")" "$(basename "$f")" > "$f.sha256" ;;
  esac
done
