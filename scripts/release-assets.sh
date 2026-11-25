#!/usr/bin/env bash
# Prepara a pasta de um release: confere os .sha256 gerados na compilação, tira a versão
# dos nomes (para os links fixos .../releases/latest/download/<nome> do README valerem em
# todo release), gera um SHA256SUMS único e as notas com a versão do Firefox de cada pacote.
#   uso: scripts/release-assets.sh <pasta> [arquivo-de-notas]
set -euo pipefail
dir="${1:?uso: $0 <pasta> [arquivo-de-notas]}"
notes="${2:-/dev/null}"
REPO_URL="https://github.com/vcastw/coldfox"
# Nomes que o README e scripts/install-linux.sh apontam. Faltou um: o release não sai.
REQUIRED="coldfox-linux-x86_64.tar.xz coldfox-windows-x86_64-setup.exe coldfox-windows-x86_64.zip
coldfox-macos-arm64.dmg coldfox-android-arm64-v8a.apk"
die() { echo "erro: $*" >&2; exit 1; }

cd "$dir"
shopt -s nullglob
sums=(coldfox-*.sha256)
[ "${#sums[@]}" -gt 0 ] || die "nenhum .sha256 em $dir"
for s in "${sums[@]}"; do
  [ -f "${s%.sha256}" ] || die "$s sem o arquivo correspondente"
  sha256sum -c --quiet "$s" || die "SHA-256 não confere: ${s%.sha256}"
done
for f in coldfox-*; do
  case "$f" in *.sha256) continue ;; esac
  [ -f "$f.sha256" ] || die "$f sem .sha256"
done
rm -f -- "${sums[@]}"

versions=""
for f in coldfox-*; do
  [[ "$f" =~ ^coldfox-([0-9]+(\.[0-9]+)*)-(.+)$ ]] || die "nome inesperado: $f"
  new="coldfox-${BASH_REMATCH[3]}"
  new="${new/-android-fenix-/-android-}"
  [ ! -e "$new" ] || die "dois pacotes viram $new"
  mv -- "$f" "$new"
  versions+="| [\`$new\`]($REPO_URL/releases/latest/download/$new) | Firefox ${BASH_REMATCH[1]} |"$'\n'
done
for f in $REQUIRED; do [ -f "$f" ] || die "falta $f"; done
sha256sum coldfox-* > SHA256SUMS

{
  echo "Como instalar: [Baixar e usar]($REPO_URL#baixar)."
  echo
  echo "| Arquivo | Base |"
  echo "|---|---|"
  printf '%s' "$versions"
  echo
  echo "Conferir: \`sha256sum -c --ignore-missing SHA256SUMS\` e \`gh attestation verify <arquivo> -R vcastw/coldfox\`."
} > "$notes"
