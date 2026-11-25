<p align="center"><img src="branding/logo.svg" width="128" alt="Logo do ColdFox"></p>

# ColdFox

Fork do Firefox focado em **leveza, desempenho e minimalismo, com segurança em primeiro lugar** —
sem telemetria e sem serviços de big techs ligados por padrão.

## Baixar

| Sistema | Download direto (sempre a versão mais recente) |
|---|---|
| **Windows** 10/11, 64 bits | [**Instalador (.exe)**](https://github.com/vcastw/coldfox/releases/latest/download/coldfox-windows-x86_64-setup.exe) · [portátil (.zip)](https://github.com/vcastw/coldfox/releases/latest/download/coldfox-windows-x86_64.zip) |
| **macOS**, Apple Silicon | [**Imagem de disco (.dmg)**](https://github.com/vcastw/coldfox/releases/latest/download/coldfox-macos-arm64.dmg) |
| **Linux**, x86_64 | [**Pacote (.tar.xz)**](https://github.com/vcastw/coldfox/releases/latest/download/coldfox-linux-x86_64.tar.xz) ou o [instalador de um comando](#linux) |
| **Android**, arm64 | [**APK**](https://github.com/vcastw/coldfox/releases/latest/download/coldfox-android-arm64-v8a.apk) |

Como instalar em cada sistema: [Instalar](#instalar). Todas as versões e os arquivos de
conferência: [Releases](https://github.com/vcastw/coldfox/releases).

> **Estado do projeto:** inicial. As quatro plataformas compilam no CI; em Linux, macOS e
> Windows o binário final é testado antes de ser publicado — veja [Plataformas](#plataformas).

## Plataformas

| Plataforma | Base | Pacote gerado | Estado |
|---|---|---|---|
| Linux x86_64 | Firefox ESR | `.tar.xz` | **Compilado e testado no CI** (prefs, políticas, extensões e rede no binário final) |
| Windows x86_64 | Firefox ESR | `.zip` + instalador `.exe` | **Compilado e testado no CI** (prefs, políticas, extensões e rede no binário final) |
| macOS (Apple Silicon) | Firefox ESR | `.dmg` | **Compilado e testado no CI** (prefs, políticas, extensões e rede no binário final) |
| Android (arm64) | Firefox estável (não existe ESR para Android) | `.apk` | **Compilado no CI**; sem teste em aparelho |

Em **qualquer desktop** dá para usar hoje a configuração do ColdFox sobre um Firefox já
instalado — veja [Usar só a configuração](#usar-só-a-configuração-num-firefox-já-instalado).

## Instalar

**Windows** — execute o instalador. No aviso do SmartScreen, clique em **Mais informações →
Executar assim mesmo** (o instalador não é assinado). Sem instalar: extraia o `.zip` e abra
`coldfox.exe`.

**macOS** — abra o `.dmg` e arraste o ColdFox para Aplicativos. Antes da primeira abertura,
no Terminal (o app não é notarizado pela Apple):

```bash
xattr -dr com.apple.quarantine /Applications/ColdFox.app
```

<a id="linux"></a>**Linux** — o instalador baixa a versão mais recente, confere o SHA-256,
instala em `~/.local/opt/coldfox` (sem root) e cria o atalho no menu e o comando `coldfox`.
Rodar de novo atualiza. Baixe, leia se quiser, e execute:

```bash
curl -fLO https://raw.githubusercontent.com/vcastw/coldfox/main/scripts/install-linux.sh
```

```bash
bash install-linux.sh
```

Manual: `tar -xf coldfox-linux-x86_64.tar.xz` e depois `./coldfox/coldfox`, em qualquer pasta.

**Android** — abra o `.apk` no aparelho e permita a instalação de fonte desconhecida. Os
outros `.apk` do release são para aparelhos antigos de 32 bits (`armeabi-v7a`) e emuladores
(`x86_64`). Versões novas instalam por cima: todo release é assinado com a mesma chave.

**Conferir o download** (recomendado): o release traz um `SHA256SUMS` e cada arquivo tem um
atestado de que foi compilado pelo workflow deste repositório.

```bash
sha256sum -c --ignore-missing SHA256SUMS
```

```bash
gh attestation verify coldfox-<arquivo> -R vcastw/coldfox
```

**No primeiro uso**
- O ColdFox usa um perfil próprio: não mexe no Firefox instalado nem importa nada sozinho.
  Para trazer favoritos e senhas: menu → Favoritos → Gerenciar favoritos → Importar e backup.
- uBlock Origin, Privacy Badger e Decentraleyes são baixados da loja da Mozilla nos primeiros
  segundos com internet. Dá para remover qualquer um em Extensões.
- O buscador é o DuckDuckGo; troque em Configurações → Pesquisa.
- Alguns sites quebram com as proteções ligadas (vídeo com DRM, sites só em HTTP). Veja
  [Decisões com custo](#decisões-com-custo--leia-antes-de-usar) para o que religar.

**Atualizações** — não há atualizador automático. Assine os releases do repositório
(**Watch → Custom → Releases**) e instale a versão nova por cima quando sair; ela traz as
correções de segurança do Firefox. Todo dia o workflow **Versão nova do Firefox** confere
se a Mozilla publicou uma versão mais nova que a do último release e, se sim, abre uma issue
(ou, com a variável `AUTO_RELEASE=true` no repositório, já dispara o release).

## Como funciona

O ColdFox não copia o código do Firefox para este repositório. Como LibreWolf e Mullvad Browser,
ele é um conjunto pequeno e auditável de arquivos aplicado sobre o código-fonte oficial:

| Caminho | O que é |
|---|---|
| `version`, `version-android` | Versão base do Firefox (`esr-latest` / `release-latest`, ou uma versão fixa) |
| `mozconfig` | Opções de compilação de todas as plataformas |
| `settings/coldfox.js` | Prefs padrão/travadas, cada uma com o motivo |
| `settings/policies.json` | Políticas do desktop (buscador, extensões de fábrica, IA, mensagens) |
| `branding/` | Nome e logo (`logo.svg`); ícones, wordmarks, janela "Sobre" e imagens do instalador são gerados dele por `tools/gen-branding.py` |
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
  servidor do Google; geolocalização via BeaconDB em vez do Google; o DNS criptografado (DoH) não é
  ativado sozinho e, quando você o liga, usa o Quad9 (fundação suíça sem fins lucrativos,
  que bloqueia domínios de malware) em vez da Cloudflare; o codec OpenH264 não é baixado da Cisco.
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

**Mais leve**
- Fora da compilação: telemetria (inclusive o programa `pingsender`), crash reporter,
  atualizador, controle parental e a varredura de redes Wi-Fi; no Windows, também o serviço de manutenção e o agente de
  navegador padrão.
- Desligados: pré-carregamento da nova aba, miniaturas de páginas, clima e "buscas em alta"
  na barra de endereço, botão "Informar problema no site", ofertas do Relay/Lockwise e
  mudanças de configuração remotas (Nimbus).
- Memória: no máximo 2 páginas guardadas inteiras para o "voltar" instantâneo (o Firefox
  guarda até 8) e abas inativas descarregadas quando a RAM acaba.

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

No Android, as mesmas três são instaladas na primeira abertura do app (veja [Notas por plataforma](#notas-por-plataforma)).

## Conexões que continuam existindo (e por quê)

Transparência em vez de promessa de "zero conexões". Medido abrindo o ColdFox com um perfil
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
  cada novo release do ColdFox. Navegador desatualizado é o maior risco de segurança que existe —
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

Forma mais rápida (e hoje a recomendada) de ter o comportamento do ColdFox no desktop,
mantendo as atualizações de segurança oficiais da Mozilla:

```bash
scripts/apply-config.sh /usr/lib/firefox                      # Linux
scripts/apply-config.sh /Applications/Firefox.app             # macOS
scripts/apply-config.sh "/c/Program Files/Mozilla Firefox"    # Windows (Git Bash, como administrador)
```

Isso copia dois arquivos para a instalação: `browser/defaults/preferences/coldfox.js` e
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

Variáveis: `COLDFOX_FAST_BUILD=1` (sem LTO, menos RAM), `COLDFOX_PGO=1` (PGO),
`COLDFOX_SKIP_BOOTSTRAP=1` (toolchain já instalada), `COLDFOX_ANDROID_ABI=aarch64|armv7|x86_64`.

O workflow **Build** do GitHub Actions compila as quatro plataformas. Para publicar um
release: crie uma tag `vX.Y` ou dispare o workflow com o campo `release_tag` preenchido.
Os arquivos saem sem a versão no nome (`scripts/release-assets.sh`), para os links de
[Baixar](#baixar) valerem em todo release; a versão do Firefox de cada um fica nas notas.

### Notas por plataforma

**Windows** — o instalador não é assinado: o SmartScreen vai avisar "aplicativo não reconhecido".
Assinatura de código exige um certificado pago.

**macOS** — o app não é assinado nem notarizado pela Apple (exige conta de desenvolvedor paga).
Na primeira execução: `xattr -dr com.apple.quarantine /Applications/ColdFox.app`.

**Android** — é outro aplicativo (Fenix). Os ajustes ficam em `scripts/prepare-android.sh`
e cada um falha a compilação se o código da Mozilla mudar, em vez de passar pela metade:
- Telemetria (Glean), marketing (Adjust), relatórios de falha (Sentry) e Play Integrity
  desligados na compilação; as chaves de telemetria e estudos vêm desligadas.
- Extensões de fábrica instaladas da loja da Mozilla na primeira abertura, sem diálogo só
  para as que o próprio app pediu (`android/DefaultAddons.kt`). Removida, não volta.
- DuckDuckGo como buscador padrão, Safe Browsing do Google desligado, proteção contra
  rastreamento rigorosa, HTTPS em todas as abas e GPC; sem atalhos patrocinados, Pocket,
  Firefox Suggest e sugestões de busca; sem apresentação inicial nem Termos de Uso da Mozilla.
- As prefs de `settings/coldfox.js` entram no GeckoView; `policies.json` não existe no Android.
- Nome, ID (`io.github.coldfox`), ícone e wordmarks são do ColdFox. Ainda restam textos
  "Firefox" em telas secundárias (sincronização, traduções) e nos ícones alternativos.
- O APK de todo release é assinado com a chave do projeto; sem ela o release não sai
  (veja [Assinatura](#assinatura)).

## Assinatura

| Plataforma | Estado | O que falta |
|---|---|---|
| Android | **Assinado com a chave do projeto.** O release é recusado sem a chave ou com chave de debug. | Só a configuração inicial, uma vez (abaixo). |
| Windows | Sem assinatura: o SmartScreen avisa "aplicativo não reconhecido". | Um certificado de assinatura de código, emitido por uma autoridade certificadora. Para projeto de código aberto há o programa gratuito da [SignPath Foundation](https://signpath.org/) (depende de aprovação); os pagos custam a partir de algumas dezenas de dólares por ano. |
| macOS | Sem assinatura nem notarização: exige o comando `xattr` de [Instalar](#instalar). | Conta do Apple Developer Program (US$ 99 por ano); não existe alternativa gratuita. |
| Linux | Não se aplica (não há assinatura de sistema para `.tar.xz`). | — |

Em todas as plataformas, cada arquivo de release tem um atestado de procedência (Sigstore)
que prova que ele saiu do workflow deste repositório — veja [Instalar](#instalar).

**Chave do Android (uma vez, por quem mantém o projeto)** — num computador com Java e o
`gh` autenticado:

```bash
tools/gerar-chave-android.sh
```

Cria o keystore em `~/coldfox-chave-android` e cadastra os secrets `ANDROID_KEYSTORE_B64`,
`ANDROID_KEYSTORE_PASSWORD` e `ANDROID_KEY_ALIAS` no ambiente `release` do repositório (sem
o `gh`, mostra o que colar em Settings > Environments). **Guarde essa pasta em lugar seguro e
fora do git:** quem tem a chave publica atualizações em nome do ColdFox, e quem a perde
nunca mais atualiza o app já instalado. A impressão digital do certificado aparece no resumo
do job `android-sign` de cada release.

## Testes

```bash
tests/lint.sh                                    # formato das prefs, JSON, actions fixadas, chave da Mozilla, shellcheck, release e instalador
tests/check-runtime.py /caminho/do/coldfox      # sobe o navegador headless e confere cada pref e política
tests/check-extensions.py /caminho/do/coldfox   # extensões de fábrica instaladas, ativas e assinadas
tests/check-network.py /caminho/do/coldfox      # toda conexão em 2 min parado está em tests/allowed-hosts.txt
```

O CI roda todos a cada push (sobre o Firefox ESR oficial com a configuração do ColdFox) e,
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
- [x] **As quatro plataformas compilam no GitHub Actions** (Linux, macOS, Windows, Android);
  em Linux, macOS e Windows o binário é testado (prefs, extensões, rede) antes de publicar
- [x] APK de release sempre assinado com a chave do projeto (sem ela o release não sai)
- [x] Releases com links de download fixos, `SHA256SUMS` e atestado de procedência

Pendente:
- [ ] Android: debranding dos textos restantes (sincronização, traduções) e ícones alternativos;
  teste em aparelho real
- [ ] macOS: fundo da imagem de disco (`.dmg`) e ícone do volume ainda são os genéricos "unofficial"
- [ ] Patch para remover Normandy e Health Report da compilação (hoje desligados por pref travada)
- [ ] Assinatura de código no Windows e no macOS (dependem de certificado; veja [Assinatura](#assinatura))
- [x] Conferência diária de versão nova do Firefox (issue de aviso ou release automático)
- [ ] Aviso de atualização dentro do navegador
- [ ] Linux arm64, macOS Intel, Flatpak/AppImage
- [ ] Medições de desempenho e memória publicadas contra o Firefox padrão

## Licença e marcas

Código sob a [Mozilla Public License 2.0](LICENSE). ColdFox é um projeto independente, **não
afiliado nem endossado pela Mozilla**. "Firefox" e "Mozilla" são marcas da Mozilla Foundation.
