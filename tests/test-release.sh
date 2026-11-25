#!/usr/bin/env bash
# Testa scripts/release-assets.sh e scripts/install-linux.sh com pacotes falsos.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FALHA: $*"; exit 1; }

mk() { # mk <pasta>: os arquivos que os jobs de compilação entregam
  mkdir -p "$1"
  local f
  for f in coldfox-153.8.0-linux-x86_64.tar.xz coldfox-153.8.0-windows-x86_64.zip \
           coldfox-153.8.0-windows-x86_64-setup.exe coldfox-153.8.0-macos-arm64.dmg \
           coldfox-161.0-android-fenix-arm64-v8a.apk coldfox-161.0-android-fenix-x86_64.apk; do
    echo "$f" > "$1/$f"
    (cd "$1" && sha256sum "$f" > "$f.sha256")
  done
}

mk "$tmp/ok"
"$ROOT/scripts/release-assets.sh" "$tmp/ok" "$tmp/notas.md"
for f in coldfox-linux-x86_64.tar.xz coldfox-windows-x86_64-setup.exe coldfox-windows-x86_64.zip \
         coldfox-macos-arm64.dmg coldfox-android-arm64-v8a.apk coldfox-android-x86_64.apk SHA256SUMS; do
  [ -f "$tmp/ok/$f" ] || fail "faltou $f"
done
[ "$(find "$tmp/ok" -type f | wc -l)" = 7 ] || fail "sobrou arquivo além dos pacotes e do SHA256SUMS"
(cd "$tmp/ok" && sha256sum -c --quiet SHA256SUMS) || fail "SHA256SUMS não confere"
grep -q 'coldfox-macos-arm64.dmg.*Firefox 153.8.0' "$tmp/notas.md" || fail "notas sem a versão base"

mk "$tmp/adulterado"; echo x >> "$tmp/adulterado/coldfox-153.8.0-macos-arm64.dmg"
! "$ROOT/scripts/release-assets.sh" "$tmp/adulterado" >/dev/null 2>&1 || fail "aceitou pacote que não bate com o .sha256"
mk "$tmp/semsoma"; rm "$tmp/semsoma/coldfox-153.8.0-macos-arm64.dmg.sha256"
! "$ROOT/scripts/release-assets.sh" "$tmp/semsoma" >/dev/null 2>&1 || fail "aceitou pacote sem .sha256"
mk "$tmp/incompleto"; rm "$tmp/incompleto"/coldfox-153.8.0-windows-x86_64-setup.exe*
! "$ROOT/scripts/release-assets.sh" "$tmp/incompleto" >/dev/null 2>&1 || fail "aceitou release sem o instalador do Windows"
echo "ok: release-assets.sh"

# Todo link de download direto do README aponta para um nome que o release publica.
links="$(grep -oE 'releases/latest/download/[A-Za-z0-9._-]+' "$ROOT/README.md" | sort -u || true)"
[ -n "$links" ] || fail "README sem links de download direto"
for l in $links; do [ -f "$tmp/ok/${l##*/}" ] || fail "README aponta para ${l##*/}, que o release não publica"; done
echo "ok: links de download do README"

# Instalador do Linux com um pacote local (o caminho de download precisa de um release real).
mkdir -p "$tmp/pkg/coldfox" "$tmp/home"
printf '#!/bin/sh\necho coldfox-falso\n' > "$tmp/pkg/coldfox/coldfox"; chmod +x "$tmp/pkg/coldfox/coldfox"
tar -cJf "$tmp/coldfox-linux-x86_64.tar.xz" -C "$tmp/pkg" coldfox
for _ in 1 2; do # a segunda vez é a atualização por cima
  HOME="$tmp/home" COLDFOX_PREFIX="$tmp/home/opt" "$ROOT/scripts/install-linux.sh" "$tmp/coldfox-linux-x86_64.tar.xz" >/dev/null
done
[ "$("$tmp/home/.local/bin/coldfox")" = coldfox-falso ] || fail "comando coldfox não funciona"
grep -q "^Exec=$tmp/home/opt/coldfox/coldfox %u$" "$tmp/home/.local/share/applications/coldfox.desktop" || fail "atalho errado"
[ -z "$(find "$tmp/home/opt" -name '.coldfox-novo*')" ] || fail "sobrou pasta temporária"
echo lixo > "$tmp/ruim.tar.xz"
! HOME="$tmp/home" COLDFOX_PREFIX="$tmp/home/opt" "$ROOT/scripts/install-linux.sh" "$tmp/ruim.tar.xz" >/dev/null 2>&1 || fail "aceitou pacote inválido"
[ "$("$tmp/home/.local/bin/coldfox")" = coldfox-falso ] || fail "pacote inválido apagou a instalação existente"
echo "ok: install-linux.sh"

# Gerador da chave do Android: cria um keystore que abre com a senha gravada e não sobrescreve.
if command -v keytool >/dev/null; then
  COLDFOX_SEM_GH=1 "$ROOT/tools/gerar-chave-android.sh" "$tmp/chave" >/dev/null
  COLDFOX_KS_PASS="$(cat "$tmp/chave/senha.txt")" keytool -list -keystore "$tmp/chave/coldfox-release.jks" \
    -storepass:env COLDFOX_KS_PASS -alias coldfox >/dev/null 2>&1 || fail "keystore não abre com a senha gravada"
  base64 -d < "$tmp/chave/keystore-base64.txt" | cmp -s - "$tmp/chave/coldfox-release.jks" || fail "base64 do keystore não confere"
  grep -qE '^([0-9A-F]{2}:){31}[0-9A-F]{2}$' "$tmp/chave/impressao-digital-sha256.txt" || fail "impressão digital ausente"
  [ "$(stat -c %a "$tmp/chave/senha.txt")" = 600 ] || fail "senha legível por outros usuários"
  ! COLDFOX_SEM_GH=1 "$ROOT/tools/gerar-chave-android.sh" "$tmp/chave" >/dev/null 2>&1 || fail "sobrescreveu uma chave existente"
  echo "ok: gerar-chave-android.sh"
fi

# Detecção de versão nova do Firefox.
cat > "$tmp/atuais.json" <<'J'
{"FIREFOX_ESR": "153.9.0esr", "LATEST_FIREFOX_VERSION": "161.0"}
J
nova() { "$ROOT/scripts/versao-nova.py" "$1" "$tmp/notas.md" "$tmp/atuais.json"; }
out="$(nova v0.2)" # notas de 153.8.0 e 161.0 (geradas acima)
grep -qx 'nova=true' <<< "$out" || fail "não viu o ESR novo"
grep -qx 'tag=v0.3' <<< "$out" || fail "próxima tag errada: $out"
grep -q 'desktop 153.8.0 → 153.9.0' <<< "$out" || fail "resumo errado: $out"
grep -q 'Android' <<< "$out" && fail "Android sem mudança apareceu no resumo"
sed -i 's/153.9.0esr/153.8.0esr/' "$tmp/atuais.json"
grep -qx 'nova=false' <<< "$(nova v0.2)" || fail "acusou versão nova sem ter"
sed -i 's/"161.0"/"161.0.1"/' "$tmp/atuais.json"
grep -qx 'nova=true' <<< "$(nova v0.2)" || fail "não viu o Android novo"
echo x > "$tmp/notas.md"
grep -qx 'nova=true' <<< "$(nova v1.9)" || fail "notas sem tabela deveriam contar como desatualizado"
grep -qx 'tag=v1.10' <<< "$(nova v1.9)" || fail "próxima tag de v1.9 deveria ser v1.10"
echo "ok: versao-nova.py"
