#!/usr/bin/env bash
# Instala (ou atualiza) o ColdFox no Linux, só para o seu usuário, sem root:
#   ~/.local/opt/coldfox, comando `coldfox` em ~/.local/bin e atalho no menu.
#   scripts/install-linux.sh                         baixa o release mais recente
#   scripts/install-linux.sh coldfox-linux-*.tar.xz  usa um pacote já baixado
# O download é conferido com o SHA256SUMS do release (pega arquivo corrompido) e, havendo
# o `gh` autenticado, com o atestado de procedência (pega pacote trocado no release).
set -euo pipefail
REPO="vcastw/coldfox"
FILE="coldfox-linux-x86_64.tar.xz"
BASE="https://github.com/$REPO/releases/latest/download"
PREFIX="${COLDFOX_PREFIX:-$HOME/.local/opt}"
die() { echo "erro: $*" >&2; exit 1; }

[ "$(uname -s)" = Linux ] || die "este instalador é só para Linux"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
if [ $# -ge 1 ]; then
  pkg="$1"; [ -f "$pkg" ] || die "arquivo não encontrado: $pkg"
else
  [ "$(uname -m)" = x86_64 ] || die "só há pacote para x86_64 (este sistema: $(uname -m))"
  pkg="$tmp/$FILE"
  echo "Baixando $FILE..."
  curl -fL --proto '=https' --tlsv1.2 --retry 3 -o "$pkg" "$BASE/$FILE"
  curl -fsL --proto '=https' --tlsv1.2 --retry 3 -o "$tmp/SHA256SUMS" "$BASE/SHA256SUMS"
  (cd "$tmp" && grep -F "  $FILE" SHA256SUMS | sha256sum -c --quiet -) || die "SHA-256 não confere"
  if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    gh attestation verify "$pkg" -R "$REPO" >/dev/null || die "atestado de procedência não confere"
    echo "Atestado de procedência conferido."
  else
    echo "Aviso: sem o gh autenticado, o atestado de procedência não foi conferido."
  fi
fi

# Extrai ao lado e troca de uma vez: uma atualização interrompida não deixa meia instalação.
mkdir -p "$PREFIX" "$HOME/.local/bin" "$HOME/.local/share/applications"
new="$(mktemp -d "$PREFIX/.coldfox-novo.XXXXXX")"
tar -xf "$pkg" -C "$new" 2>/dev/null || { rm -rf "$new"; die "pacote inválido: $pkg"; }
[ -x "$new/coldfox/coldfox" ] || { rm -rf "$new"; die "o pacote não contém coldfox/coldfox"; }
rm -rf "$PREFIX/coldfox"
mv "$new/coldfox" "$PREFIX/coldfox"
rmdir "$new"

ln -sf "$PREFIX/coldfox/coldfox" "$HOME/.local/bin/coldfox"
cat > "$HOME/.local/share/applications/coldfox.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=ColdFox
Comment=Navegador leve e privado
Exec=$PREFIX/coldfox/coldfox %u
Icon=$PREFIX/coldfox/browser/chrome/icons/default/default128.png
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
StartupWMClass=coldfox
DESKTOP
echo "ColdFox instalado em $PREFIX/coldfox. Abra pelo menu ou com: coldfox"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "(~/.local/bin não está no PATH; use $PREFIX/coldfox/coldfox)" ;; esac
