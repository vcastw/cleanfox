# Patches

Arquivos `*.patch` são aplicados sobre o código-fonte do Firefox em ordem alfabética por
`scripts/prepare.sh` (`patch -p1`). Use prefixo numérico: `0001-descricao.patch`.

- `patches/*.patch` — desktop (Linux, Windows, macOS), sobre o Firefox ESR.
- `patches/android/*.patch` — Android, sobre o Firefox estável.

Regras:

- **Patch é o último recurso.** Se dá para resolver com pref (`settings/cleanfox.js`),
  política (`settings/policies.json`) ou opção de build (`mozconfig`), faça lá.
  Cada patch precisa ser conferido a cada nova versão do Firefox (o CI semanal avisa).
- Um patch = uma mudança. O texto antes do primeiro `---` explica o motivo.
- Edições que dependem de conteúdo gerado (prefs, arte) ficam em `scripts/prepare*.sh`.
