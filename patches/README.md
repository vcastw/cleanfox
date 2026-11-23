# Patches

Arquivos `*.patch` nesta pasta são aplicados sobre o código-fonte do Firefox em ordem
alfabética por `scripts/prepare.sh` (`patch -p1`). Use prefixo numérico: `0001-descricao.patch`.

Regras:

- **Patch é o último recurso.** Se dá para resolver com pref (`settings/cleanfox.cfg`),
  política (`settings/distribution/policies.json`) ou opção de build (`mozconfig`), faça lá.
  Cada patch precisa ser refeito a cada nova versão ESR.
- Um patch = uma mudança. O cabeçalho do arquivo explica o motivo.
- Gere a partir de `build/src`: `diff -u a/arquivo b/arquivo` ou `git diff` em um checkout do Firefox.
