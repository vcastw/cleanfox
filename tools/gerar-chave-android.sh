#!/usr/bin/env bash
# Gera a chave de assinatura do APK do ColdFox e cadastra os três secrets que o job
# android-sign usa (ambiente "release" do repositório). Rode UMA vez, no seu computador:
#   tools/gerar-chave-android.sh [pasta-de-saída]      (padrão: ~/coldfox-chave-android)
# Precisa do keytool (vem com o Java) e, para cadastrar sozinho, do gh autenticado.
#
# GUARDE a pasta gerada num lugar seguro e fora do git. Quem tem a chave publica
# atualizações em nome do ColdFox; quem a perde nunca mais atualiza o app instalado.
set -euo pipefail
REPO="${COLDFOX_REPO:-vcastw/coldfox}"
ALIAS="coldfox"
out="${1:-$HOME/coldfox-chave-android}"
die() { echo "erro: $*" >&2; exit 1; }

command -v keytool >/dev/null || die "keytool não encontrado (instale um JDK)"
ks="$out/coldfox-release.jks"
[ ! -e "$ks" ] || die "$ks já existe; não sobrescrevo uma chave"
umask 077
mkdir -p "$out"
COLDFOX_KS_PASS="$(head -c 24 /dev/urandom | base64 | tr -d '/+=\n')"
export COLDFOX_KS_PASS
# 30 anos: a chave precisa valer mais do que o app.
keytool -genkeypair -keystore "$ks" -storetype PKCS12 -storepass:env COLDFOX_KS_PASS \
  -alias "$ALIAS" -keyalg RSA -keysize 4096 -validity 10950 -dname "CN=ColdFox" 2>/dev/null
printf '%s\n' "$COLDFOX_KS_PASS" > "$out/senha.txt"
keytool -list -v -keystore "$ks" -storepass:env COLDFOX_KS_PASS -alias "$ALIAS" 2>/dev/null \
  | sed -n 's/^[[:space:]]*SHA256: //p' | head -1 > "$out/impressao-digital-sha256.txt"
echo "Chave criada em $out (keystore, senha.txt e impressao-digital-sha256.txt)."
echo "Impressão digital SHA-256: $(cat "$out/impressao-digital-sha256.txt")"

if [ -z "${COLDFOX_SEM_GH:-}" ] && command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  base64 < "$ks" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_B64 -R "$REPO" --env release
  printf '%s' "$COLDFOX_KS_PASS" | gh secret set ANDROID_KEYSTORE_PASSWORD -R "$REPO" --env release
  printf '%s' "$ALIAS" | gh secret set ANDROID_KEY_ALIAS -R "$REPO" --env release
  echo "Secrets cadastrados no ambiente 'release' de $REPO."
else
  base64 < "$ks" | tr -d '\n' > "$out/keystore-base64.txt"
  cat <<MSG
Cadastre em https://github.com/$REPO/settings/environments (ambiente "release" >
Environment secrets):
  ANDROID_KEYSTORE_B64       conteúdo de $out/keystore-base64.txt
  ANDROID_KEYSTORE_PASSWORD  conteúdo de $out/senha.txt
  ANDROID_KEY_ALIAS          $ALIAS
MSG
fi
