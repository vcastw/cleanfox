# CleanFox

Fork do Firefox focado em **leveza, desempenho e minimalismo, com segurança em primeiro lugar** —
sem telemetria e sem serviços de big techs ligados por padrão.

> **Estado do projeto:** inicial. A configuração (prefs e políticas) é testada automaticamente
> contra o Firefox ESR real. A compilação completa do binário CleanFox ainda **não foi validada
> de ponta a ponta** — veja [Estado e roadmap](#estado-e-roadmap).

## Como funciona

O CleanFox não copia o código do Firefox para este repositório. Como LibreWolf e Mullvad Browser,
ele é um conjunto pequeno e auditável de arquivos aplicado sobre o código-fonte oficial do
**Firefox ESR** (ciclo longo, só correções de segurança):

| Caminho | O que é |
|---|---|
| `version` | Versão do Firefox ESR usada como base (`esr-latest` ou fixa, ex. `153.7.0esr`) |
| `mozconfig` | Opções de compilação |
| `settings/cleanfox.cfg` | Prefs padrão/travadas, cada uma com o motivo |
| `settings/distribution/policies.json` | Políticas (buscador, uBlock Origin, IA, mensagens) |
| `branding/` | Nome e identidade (sem marcas da Mozilla) |
| `patches/` | Alterações no código-fonte (último recurso; hoje vazio) |
| `scripts/` | Baixar fonte, preparar, compilar, empacotar |
| `tests/` | Lint estático e teste de runtime num navegador real |

## O que muda em relação ao Firefox

**Sem coleta de dados**
- Telemetria, Health Report, estudos (Normandy/Shield), relatórios de travamento e a
  "atribuição de anúncios com privacidade": desligados e **travados** (não dá para religar pela interface).
- Código de envio de telemetria e o crash reporter não são compilados.
- Sem detecção de portal cativo, consulta de região, pré-conexões especulativas e
  system add-ons empurrados fora do ciclo de release.

**Sem big techs por padrão**
- Buscador padrão DuckDuckGo; Google, Bing, Amazon, eBay e Perplexity removidos.
- Google Safe Browsing desligado; DRM Widevine (Google) desligado; geolocalização via BeaconDB
  em vez do Google; DNS-over-HTTPS (Cloudflare) não é ativado sozinho.
- Conta Firefox/Sync desligada por padrão (reativável).

**Minimalista**
- Página inicial e nova aba em branco; sem conteúdo patrocinado, promoções, onboarding,
  recomendações ou IA embutida (chatbot, link preview, grupos de abas "inteligentes").
- Interface compacta, sem barra de favoritos por padrão.

**Segurança**
- Modo somente-HTTPS, Proteção contra Rastreamento no modo rigoroso, proteção contra
  fingerprinting, Global Privacy Control, WebRTC sem vazamento de IP local, punycode visível,
  scripts em PDF desligados, TLS 0-RTT desligado.
- uBlock Origin instalado por política.
- Compilado com `--enable-hardening`. Diferente de outros forks, **mantemos** a assinatura
  obrigatória de extensões e o sandbox RLBox das bibliotecas de terceiros.

**Desempenho** — sendo honesto: prefs não fazem milagre. O ganho vem de (1) menos serviços e
conexões em segundo plano, (2) bloqueio de conteúdo por padrão e (3) build com LTO/PGO e sem
símbolos de depuração. Não incluímos "tweaks" de rede ou cache sem efeito medido.

## Conexões que continuam existindo (e por quê)

Transparência em vez de promessa de "zero conexões":

| Destino | Motivo | Como desligar |
|---|---|---|
| `firefox.settings.services.mozilla.com` | Revogação de certificados (CRLite), bloqueio de extensões maliciosas, listas de rastreadores. **Download apenas; é segurança.** | `services.settings.server` |
| `addons.mozilla.org` | Instalar/atualizar o uBlock Origin e suas extensões | Remover `ExtensionSettings` da política; `extensions.update.enabled` |
| Listas de filtros do uBlock Origin | Bloqueio de anúncios/malware | Configurações do uBO |
| Servidor de push da Mozilla | Só se você aceitar notificações de algum site | `dom.push.connection.enabled` |

## Decisões com custo — leia antes de usar

- **Safe Browsing desligado.** Atende ao "sem Google", mas remove uma camada de proteção contra
  phishing/malware. As listas do uBlock Origin cobrem parte disso, não tudo. Para religar:
  ative "Bloquear conteúdo perigoso e enganoso" e restaure as prefs `browser.safebrowsing.provider.google*`.
- **Sem atualizador automático.** O atualizador da Mozilla é removido; você precisa instalar
  cada novo release do CleanFox. Navegador desatualizado é o maior risco de segurança que existe —
  enquanto o projeto não publicar releases a cada ESR, prefira usar só a configuração (abaixo).
- **DRM desligado.** Netflix, Spotify etc. não tocam até reativar o DRM nas Configurações.

## Usar só a configuração, num Firefox já instalado

Forma mais rápida (e hoje a recomendada) de ter o comportamento do CleanFox, mantendo as
atualizações de segurança oficiais:

```bash
scripts/apply-config.sh /caminho/da/instalacao/do/firefox
```

## Compilar

Requisitos: Linux x86_64, ~40 GB de disco, 16 GB de RAM, Python 3, `curl`, `jq`, `patch`.

```bash
make fetch      # baixa o fonte do Firefox ESR e confere o SHA-512
make prepare    # aplica branding, patches e mozconfig
make build      # mach bootstrap + build + package (1h a várias horas)
make package    # injeta a configuração e gera dist/cleanfox-<versão>-linux-x86_64.tar.xz
```

Variáveis: `CLEANFOX_FAST_BUILD=1` (sem LTO, menos RAM), `CLEANFOX_PGO=1` (PGO),
`CLEANFOX_SKIP_BOOTSTRAP=1` (toolchain já instalada).

## Testes

```bash
tests/lint.sh                                 # JSON, sintaxe, formato das prefs, shellcheck
tests/check-runtime.py /caminho/do/firefox    # sobe o navegador headless e confere cada pref e política
```

O CI roda os dois a cada push, aplicando a configuração sobre o Firefox ESR oficial.

## Estado e roadmap

Feito e verificado (contra o Firefox ESR 153.7.0):
- [x] Todas as prefs e políticas aceitas pelo navegador em execução (`tests/check-runtime.py`)
- [x] `fetch` e `prepare` executados; todas as opções do `mozconfig` existem no código-fonte

Pendente:
- [ ] **Primeira compilação completa** (`make build` / `make package` ainda não foram executados)
- [ ] Ícone e identidade visual próprios (hoje usa os ícones genéricos "unofficial" do Firefox)
- [ ] Patch para remover Normandy e Health Report da compilação (hoje desligados por pref travada)
- [ ] Releases automáticos a cada ESR e mecanismo de aviso de atualização
- [ ] Windows e macOS; pacotes Flatpak/AppImage
- [ ] Medições de desempenho e memória publicadas contra o Firefox padrão

## Licença e marcas

Código sob a [Mozilla Public License 2.0](LICENSE). CleanFox é um projeto independente, **não
afiliado nem endossado pela Mozilla**. "Firefox" e "Mozilla" são marcas da Mozilla Foundation.
