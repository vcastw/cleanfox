#!/usr/bin/env bash
# Compilação do ColdFox para Windows dentro do shell do MozillaBuild (usado pelo CI).
set -euo pipefail
cd "$(dirname "$0")/.."

# python3: o MozillaBuild traz python.exe; cria o nome que os scripts esperam, se faltar.
if ! command -v python3 >/dev/null && command -v python >/dev/null; then
  mkdir -p "$HOME/bin" && ln -sf "$(command -v python)" "$HOME/bin/python3" && export PATH="$HOME/bin:$PATH"
fi

missing=""
for c in python3 curl tar xz patch gpg gpgv sha512sum make; do
  command -v "$c" >/dev/null || missing="$missing $c"
done
if [ -n "$missing" ]; then
  echo "faltam ferramentas no MozillaBuild:$missing" >&2
  echo "PATH=$PATH" >&2
  find /c/mozilla-build /c/mozilla-build/python3 -maxdepth 1 2>&1 | head -40 >&2
  exit 1
fi

scripts/fetch.sh
scripts/prepare.sh
scripts/build.sh
scripts/package.sh
