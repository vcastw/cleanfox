<p align="center"><img src="branding/logo.svg" width="128" alt="Logo do CleanFox"></p>

# CleanFox

Fork do Firefox focado em **leveza, desempenho e minimalismo, com segurança em primeiro lugar** —
sem telemetria e sem serviços de big techs ligados por padrão.

> **Estado do projeto:** inicial. Não há binários publicados ainda. A configuração é testada
> automaticamente num Firefox real; a compilação de cada plataforma está em estágios
> diferentes de validação — veja [Plataformas](#plataformas).

## Plataformas

| Plataforma | Base | Pacote gerado | Estado |
|---|---|---|---|
| Linux x86_64 | Firefox ESR | `.tar.xz` | **Compilado e testado** (prefs, políticas, extensões e rede no binário final) |
| Windows x86_64 | Firefox ESR | `.zip` + instalador `.exe` | Scripts e CI escritos, **nunca compilado** |
| macOS (Apple Silicon) | Firefox ESR | `.dmg` | Scripts e CI escritos, **nunca compilado** |
| Android (arm64) | Firefox estável (não existe ESR para Android) | `.apk` | Preparação validada, **nunca compilado**; debranding incompleto |

Em **qualquer desktop** dá para usar hoje a configuração do CleanFox sobre um Firefox já
instalado — veja [Usar só a configuração](#usar-só-a-configuração-num-firefox-já-instalado).

## Como funciona

O CleanFox não copia o código do Firefox para este repositório. Como LibreWolf e Mullvad Browser,
ele é um conjunto pequeno e auditável de arquivos aplicado sobre o código-fonte oficial:

| Caminho | O que é |
|---|---|
| `version`, `version-android` | Versão base do Firefox (`esr-latest` / `release-latest`, ou uma versão fixa) |
| `mozconfig` | Opções de compilação de todas as plataformas |
| `settings/cleanfox.js` | Prefs padrão/travadas, cada uma com o motivo |
| `settings/policies.json` | Políticas do desktop (buscador, extensões de fábrica, IA, mensagens) |
| `branding/` | Nome e logo (`logo.svg`); ícones e wordmarks são gerados dele por `tools/gen-branding.py` |
| `patches/` | Alterações no código-fonte (último recurso) |
| `scripts/` | Baixar fonte, preparar, compilar, empacotar |
| `tests/` | Lint estático e teste de runtime num navegador real |

## O que muda em relação ao Firefox

**Sem coleta de dados**
- Telemetria, Health Report, estudos (Normandy/Shield), relatórios de travamento e a
  "atribuição de anúncios com privacidade": desligados e **travados** (não dá para religar pela interface).
- Código de envio de telemetria e o crash reporter não são compilados.
- Sem detecção de portal cativo, consulta de região, pré-conexões especulativas,
  system add-ons empurrados fora do ciclo de release e conexão permanente com o serviço
  de push da Mozilla.

**Sem big techs por padrão**
- Buscador padrão DuckDuckGo; Google, Bing, Amazon, eBay e Perplexity removidos.
- Google Safe Browsing desligado; DRM Widevine (Google) desligado e sem atualização pelo
  servidor do Google; geolocalização via BeaconDB em vez do Google; DNS-over-HTTPS (Cloudflare)
  não é ativado sozinho; o codec OpenH264 não é baixado da Cisco.
- Conta Firefox/Sync desligada por padrão (reativável).

**Minimalista**
- Página inicial e nova aba em branco; sem conteúdo patrocinado, promoções, onboarding,
  recomendações ou IA embutida (chatbot, link preview, grupos de abas "inteligentes").
- Interface compacta, sem barra de favoritos por padrão.

**Segurança**
- Modo somente-HTTPS, Proteção contra Rastreamento no modo rigoroso, proteção contra
  fingerprinting, Global Privacy Control, WebRTC sem vazamento de IP local, punycode visível,
  scripts em PDF desligados, TLS 0-RTT desligado.
- Extensões de fábrica (abaixo), com a assinatura da Mozilla obrigatória.
- Fixação de certificados no modo estrito: domínios da Mozilla recusam até CAs instaladas
  manualmente, o que barra proxies que interceptam TLS.
- Compilado com `--enable-hardening`. Diferente de outros forks, **mantemos** a assinatura
  obrigatória de extensões e o sandbox RLBox das bibliotecas de terceiros.

**Desempenho** — sendo honesto: prefs não fazem milagre. O ganho vem de (1) menos serviços e
conexões em segundo plano, (2) bloqueio de conteúdo por padrão e (3) build com LTO/PGO e sem
símbolos de depuração. Não incluímos "tweaks" de rede ou cache sem efeito medido.

## Extensões de fábrica

Instaladas da loja da Mozilla na primeira execução, liberadas também na janela privativa.
Todas são "Recomendadas" pela Mozilla (revisadas a cada versão) e você pode removê-las.

| Extensão | O que faz |
|---|---|
| [uBlock Origin](https://addons.mozilla.org/firefox/addon/ublock-origin/) | Bloqueia anúncios, rastreadores e domínios de malware |
| [Privacy Badger](https://addons.mozilla.org/firefox/addon/privacy-badger17/) (EFF) | Bloqueia rastreadores pelo comportamento e envia o sinal de "não venda meus dados" (GPC) |
| [Decentraleyes](https://addons.mozilla.org/firefox/addon/decentraleyes/) | Serve bibliotecas comuns (jQuery, etc.) localmente, sem consultar CDNs de terceiros |

No Android ainda não vêm instaladas (veja [Notas por plataforma](#notas-por-plataforma)).

## Conexões que continuam existindo (e por quê)

Transparência em vez de promessa de "zero conexões". Medido abrindo o CleanFox com um perfil
novo e deixando-o parado por 2 minutos (`tests/check-network.py`, que roda no CI; a lista
completa e o motivo de cada host estão em `tests/allowed-hosts.txt`):

| Destino | Motivo | Como desligar |
|---|---|---|
| `firefox.settings.services.mozilla.com` | Revogação de certificados (CRLite), bloqueio de extensões maliciosas, listas de rastreadores. **Download apenas; é segurança.** | `services.settings.server` |
| `addons.mozilla.org`, `versioncheck-bg.addons.mozilla.org` | Instalar as extensões de fábrica e buscar atualizações de segurança delas | Remover a extensão; `extensions.update.enabled` |
| GitHub, jsDelivr, GitLab e outros listados | Listas de filtros do uBlock Origin | Configurações do uBlock Origin |
| `www.eff.org` | Dados do Privacy Badger | Remover a extensão |

Na mesma medição, o Firefox oficial contatou 13 destinos, entre eles três do Google
(Safe Browsing, atualizador de plugins e `dl.google.com`), a Cisco (codec), serviço de
localização, estudos (Normandy), contas, push e detecção de portal cativo.

## Decisões com custo — leia antes de usar

- **Safe Browsing desligado.** Atende ao "sem Google", mas remove uma camada de proteção contra
  phishing/malware. As listas do uBlock Origin cobrem parte disso, não tudo. Para religar:
  ative "Bloquear conteúdo perigoso e enganoso" e restaure as prefs `browser.safebrowsing.provider.google*`.
- **Sem atualizador automático.** O atualizador da Mozilla é removido; você precisa instalar
  cada novo release do CleanFox. Navegador desatualizado é o maior risco de segurança que existe —
  enquanto o projeto não publicar releases a cada ESR, prefira usar só a configuração (abaixo).
- **DRM desligado.** Netflix, Spotify etc. não tocam até reativar o DRM nas Configurações.
- **Sem push em segundo plano.** Notificações de sites só chegam com a aba aberta
  (`dom.push.connection.enabled`).
- **Sem codec H.264 da Cisco.** Chamadas de vídeo usam VP8/VP9; alguns serviços antigos
  exigem H.264 (`media.gmp-manager.updateEnabled`).
- **Proxies corporativos que inspecionam TLS** não acessam domínios da Mozilla (loja de
  extensões, listas de segurança) por causa do modo estrito de fixação de certificados.
  Se você confia nesse proxy, mude `security.cert_pinning.enforcement_level` para `1`.

## Usar só a configuração, num Firefox já instalado

Forma mais rápida (e hoje a recomendada) de ter o comportamento do CleanFox no desktop,
mantendo as atualizações de segurança oficiais da Mozilla:

```bash
scripts/apply-config.sh /usr/lib/firefox                      # Linux
scripts/apply-config.sh /Applications/Firefox.app             # macOS
scripts/apply-config.sh "/c/Program Files/Mozilla Firefox"    # Windows (Git Bash, como administrador)
```

Isso copia dois arquivos para a instalação: `browser/defaults/preferences/cleanfox.js` e
`distribution/policies.json`. Para desfazer, apague-os. Atualizações do Firefox podem removê-los.

## Compilar

Cada plataforma desktop é compilada no próprio sistema; o Android compila em Linux ou macOS.
Requisitos: ~40 GB de disco, 16 GB de RAM, Python 3, `curl`, `patch`, `make`
(no Windows, tudo dentro do shell do [MozillaBuild](https://wiki.mozilla.org/MozillaBuild)).

```bash
make fetch      # baixa o fonte do Firefox e confere o SHA-512
make prepare    # aplica branding, prefs, políticas, patches e mozconfig
make build      # mach bootstrap + build + empacotamento (1h a várias horas)
make package    # recolhe os pacotes em dist/ com SHA-256
```

Para Android, acrescente `TARGET=android` a cada comando (`make TARGET=android fetch` ...).

Variáveis: `CLEANFOX_FAST_BUILD=1` (sem LTO, menos RAM), `CLEANFOX_PGO=1` (PGO),
`CLEANFOX_SKIP_BOOTSTRAP=1` (toolchain já instalada), `CLEANFOX_ANDROID_ABI=aarch64|armv7|x86_64`.

O workflow **Build** do GitHub Actions compila as quatro plataformas (disparo manual ou ao
criar uma tag `vX.Y`, que também publica o release).

### Notas por plataforma

**Windows** — o instalador não é assinado: o SmartScreen vai avisar "aplicativo não reconhecido".
Assinatura de código exige um certificado pago.

**macOS** — o app não é assinado nem notarizado pela Apple (exige conta de desenvolvedor paga).
Na primeira execução: `xattr -dr com.apple.quarantine /Applications/CleanFox.app`.

**Android** — é outro aplicativo (Fenix), com diferenças importantes:
- Telemetria (Glean), marketing (Adjust), relatórios de falha (Sentry) e Play Integrity são
  desligados na compilação pelas flags `TELEMETRY`/`CRASH_REPORTING` do próprio Fenix.
- As prefs de `settings/cleanfox.js` entram no GeckoView, mas `policies.json` **não existe no
  Android**, e ajustes que o app controla por código (buscador padrão, Safe Browsing, tela
  inicial, uBlock Origin) ainda **não** são alterados.
- Nome, ID (`io.github.cleanfox`), ícone e wordmarks são trocados, mas ainda resta arte e
  texto "Firefox" dentro do app (ícones alternativos, onboarding, strings traduzidas).
  **Não distribua o APK publicamente antes de concluir o debranding** (marcas da Mozilla).
- Para que atualizações instalem por cima, o APK precisa ser sempre assinado com a mesma
  chave. Crie um keystore e cadastre os secrets `ANDROID_KEYSTORE_B64`,
  `ANDROID_KEYSTORE_PASSWORD` e `ANDROID_KEY_ALIAS` no repositório; sem eles o CI gera um
  APK com chave de debug descartável.

## Testes

```bash
tests/lint.sh                                    # formato das prefs, JSON, actions fixadas, chave da Mozilla, shellcheck
tests/check-runtime.py /caminho/do/cleanfox      # sobe o navegador headless e confere cada pref e política
tests/check-extensions.py /caminho/do/cleanfox   # extensões de fábrica instaladas, ativas e assinadas
tests/check-network.py /caminho/do/cleanfox      # toda conexão em 2 min parado está em tests/allowed-hosts.txt
```

O CI roda todos a cada push (sobre o Firefox ESR oficial com a configuração do CleanFox) e,
toda semana, baixa o código-fonte mais recente (desktop e Android) para conferir que patches
e ajustes ainda se aplicam. Controles de segurança e lacunas conhecidas: [SECURITY.md](SECURITY.md).

## Estado e roadmap

Feito e verificado:
- [x] Todas as prefs e políticas aceitas pelo Firefox ESR 153.7.0 em execução (`tests/check-runtime.py`)
- [x] `fetch` + `prepare` executados no desktop (ESR 153.7.0) e no Android (160.0.1)
- [x] Todas as opções do `mozconfig` de desktop existem no código-fonte
- [x] Toolchain de Linux instalada com `mach bootstrap`
- [x] **Linux compilado** (64 min, sem LTO) e empacotado; no binário final, todas as prefs,
  políticas e extensões de fábrica conferidas e só conexões permitidas
- [x] Download do código-fonte recusa assinatura inválida ou de outra chave (testado)

Pendente:
- [ ] **Compilações de Windows, macOS e Android** (nunca executadas)
- [ ] Android: buscador, Safe Browsing, tela inicial, extensões de fábrica e debranding completo
- [ ] `application.ini` ainda diz `Vendor=Mozilla`; `pingsender` ainda é empacotado (sem uso, telemetria desligada)
- [ ] Ícones secundários do Windows/macOS (documento, navegação privativa, instalador) ainda são os genéricos "unofficial"
- [ ] Patch para remover Normandy e Health Report da compilação (hoje desligados por pref travada)
- [ ] Assinatura de código (Windows, macOS) e chave de release do Android
- [ ] Releases automáticos a cada versão do Firefox e aviso de atualização
- [ ] Linux arm64, macOS Intel, Flatpak/AppImage
- [ ] Medições de desempenho e memória publicadas contra o Firefox padrão

## Licença e marcas

Código sob a [Mozilla Public License 2.0](LICENSE). CleanFox é um projeto independente, **não
afiliado nem endossado pela Mozilla**. "Firefox" e "Mozilla" são marcas da Mozilla Foundation.
