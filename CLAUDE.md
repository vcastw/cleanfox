# CleanFox — instruções para agentes

Fork do Firefox (ESR no desktop, estável no Android) focado em leveza, minimalismo e
segurança em primeiro lugar, sem telemetria nem serviços de big techs ligados por padrão.
Este repositório não contém o código do Firefox: é uma camada (prefs, políticas, branding,
patches, scripts) aplicada sobre o código-fonte oficial. Visão geral no `README.md`.
Português do Brasil em código, comentários, documentação e commits.

## Onde mexer (do mais barato ao mais caro)
1. `settings/cleanfox.js` — prefs; cada uma com o motivo no comentário. `locked` só para coleta de dados.
2. `settings/policies.json` — políticas do desktop (buscador, extensões de fábrica, IA).
3. `mozconfig` — opções de compilação.
4. `patches/` — último recurso; precisa ser conferido a cada versão do Firefox.

## Skills
| Quando | Skill |
|---|---|
| Pergunta de segurança, revisão de vulnerabilidade, mudança em `scripts/`, `.github/workflows/`, `keys/`, prefs de segurança ou extensões de fábrica | `security-audit` — modo de orientação (revisão focada). O fluxo completo, com relatórios, só quando uma auditoria for pedida explicitamente. |

Ao usar uma skill, diga em uma linha qual. Pedido explícito do usuário ("sem skill") tem prioridade.

## Segurança — processo obrigatório
Controles, o que prova cada um e lacunas conhecidas: `SECURITY.md`.
1. **Antes de mudar:** diga qual fronteira a mudança toca (download do fonte, CI/release,
   rede do navegador, extensões) e o que um atacante naquela posição conseguiria.
2. **Depois de mudar:** `tests/lint.sh` e, havendo um binário, os testes de runtime
   (`tests/check-runtime.py`, `tests/check-extensions.py`, `tests/check-network.py`).
   Toda falha corrigida ganha teste ou regra de lint que falhava antes.
3. **Host novo na rede** só entra em `tests/allowed-hosts.txt` com motivo; nunca para um teste passar.

Nunca enfraquecer uma proteção para um erro sumir (ex.: afrouxar fixação de certificados,
pular a assinatura GPG). Mudou um controle ou surgiu uma lacuna: atualizar `SECURITY.md`
e o `README.md` no mesmo commit.
