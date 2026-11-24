// CleanFox — prefs padrão. Arquivo de prefs comum do Firefox (sem AutoConfig).
//
// pref("nome", valor, locked); -> valor fixo, o usuário NÃO pode mudar
//                                 (usado só para telemetria/coleta de dados)
// pref("nome", valor);         -> novo valor padrão, o usuário PODE mudar
//
// Desktop: anexado a browser/app/profile/firefox.js na compilação.
// Android: anexado a mobile/android/app/geckoview-prefs.js (prefs de interface do
//          desktop são simplesmente ignoradas lá).
//
// Regra do projeto: toda pref aqui precisa de um motivo. Sem "tweaks" de efeito duvidoso.

// ===========================================================================
// 1. TELEMETRIA E COLETA DE DADOS  (travado)
// ===========================================================================
pref("toolkit.telemetry.enabled", false, locked);
pref("toolkit.telemetry.unified", false, locked);
pref("toolkit.telemetry.server", "data:,", locked);
pref("toolkit.telemetry.archive.enabled", false, locked);
pref("toolkit.telemetry.newProfilePing.enabled", false, locked);
pref("toolkit.telemetry.shutdownPingSender.enabled", false, locked);
pref("toolkit.telemetry.firstShutdownPing.enabled", false, locked);
pref("toolkit.telemetry.updatePing.enabled", false, locked);
pref("toolkit.telemetry.bhrPing.enabled", false, locked);
pref("toolkit.coverage.opt-out", true, locked);
pref("toolkit.coverage.endpoint.base", "", locked);
pref("datareporting.healthreport.uploadEnabled", false, locked);
pref("datareporting.policy.dataSubmissionEnabled", false, locked);
pref("datareporting.usage.uploadEnabled", false, locked);
pref("browser.newtabpage.activity-stream.telemetry", false, locked);
pref("browser.search.serpEventTelemetryCategorization.enabled", false, locked);
pref("dom.security.unexpected_system_load_telemetry_enabled", false, locked);

// Estudos e experimentos remotos (Normandy / Shield / Nimbus)
pref("app.shield.optoutstudies.enabled", false, locked);
pref("app.normandy.enabled", false, locked);
pref("app.normandy.api_url", "", locked);

// Relatórios de travamento
pref("breakpad.reportURL", "", locked);
pref("browser.tabs.crashReporting.sendReport", false, locked);
pref("browser.crashReports.unsubmittedCheck.enabled", false, locked);
pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false, locked);

// Medição de anúncios "privacy-preserving attribution"
pref("dom.private-attribution.submission.enabled", false, locked);

// ===========================================================================
// 2. CONEXÕES AUTOMÁTICAS EM SEGUNDO PLANO
// ===========================================================================
// Detecção de portal cativo e teste de conectividade (pingam servidores da Mozilla)
pref("network.captive-portal-service.enabled", false);
pref("captivedetect.canonicalURL", "");
pref("network.connectivity-service.enabled", false);

// Descoberta de região (consulta serviço de localização da Mozilla)
pref("browser.region.update.enabled", false);
pref("browser.region.network.url", "");

// Atualização de "system add-ons" empurrados pela Mozilla fora do ciclo de release
pref("extensions.systemAddon.update.enabled", false);
pref("extensions.systemAddon.update.url", "");

// Pré-carregamento especulativo: conecta a sites que você não pediu para abrir
pref("network.prefetch-next", false);
pref("network.dns.disablePrefetch", true);
pref("network.dns.disablePrefetchFromHTTPS", true);
pref("network.http.speculative-parallel-limit", 0);
pref("browser.urlbar.speculativeConnect.enabled", false);
pref("browser.places.speculativeConnect.enabled", false);

// DNS-over-HTTPS: desligado por escolha (5) para o Firefox não ativar sozinho
// um provedor via "rollout". O usuário pode ligá-lo em Configurações.
pref("network.trr.mode", 5);
pref("doh-rollout.disable-heuristics", true);
// Quem ligar o DNS criptografado nas Configurações usa o Quad9 (fundação suíça sem fins
// lucrativos, não registra IP, bloqueia domínios de malware e phishing), não a Cloudflare.
// A lista do menu vira só o Quad9; "Personalizado" continua disponível.
pref("network.trr.default_provider_uri", "https://dns.quad9.net/dns-query");
pref("doh-rollout.provider-list", '[{"UIName":"Quad9","uri":"https://dns.quad9.net/dns-query"}]');

// Serviço de push da Mozilla: sem isto o navegador mantém, desde a inicialização, uma
// conexão permanente com push.services.mozilla.com identificada por um ID fixo.
// Custo: notificações de sites só chegam com a aba aberta.
pref("dom.push.connection.enabled", false);

// ===========================================================================
// 3. SERVIÇOS DE "BIG TECHS"
// ===========================================================================
// Google Safe Browsing: desligado. A proteção contra sites maliciosos fica a cargo
// das listas do uBlock Origin (instalado por política). Trade-off documentado no README.
// O provedor "mozilla" (listas da Proteção contra Rastreamento) é mantido.
pref("browser.safebrowsing.malware.enabled", false);
pref("browser.safebrowsing.phishing.enabled", false);
pref("browser.safebrowsing.downloads.enabled", false);
pref("browser.safebrowsing.downloads.remote.enabled", false);
pref("browser.safebrowsing.downloads.remote.url", "");
pref("browser.safebrowsing.provider.google.updateURL", "");
pref("browser.safebrowsing.provider.google.gethashURL", "");
pref("browser.safebrowsing.provider.google4.updateURL", "");
pref("browser.safebrowsing.provider.google4.gethashURL", "");
pref("browser.safebrowsing.provider.google4.dataSharing.enabled", false);

// Geolocalização: troca o serviço do Google pelo BeaconDB (comunitário).
// Só é consultado quando você concede permissão de localização a um site.
pref("geo.provider.network.url", "https://api.beacondb.net/v1/geolocate");

// DRM (Widevine, do Google) e download automático de plugins de mídia.
// Netflix/Spotify etc. exigem reativar "Reproduzir conteúdo com DRM" nas Configurações
// e restaurar media.gmp-manager.url.
pref("media.eme.enabled", false);
pref("media.gmp-widevinecdm.enabled", false);
pref("media.gmp-manager.url", "data:text/plain,");
// Sem isto, quando o servidor acima falha o Firefox recorre a uma lista embutida e baixa
// o codec OpenH264 direto da Cisco (ciscobinary.openh264.org). Chamadas de vídeo usam VP8/VP9.
pref("media.gmp-manager.updateEnabled", false);
// Widevine reativado não deve ser baixado do servidor de atualização do Google.
pref("media.gmp-widevinecdm.allow-chromium-update", false);

// ===========================================================================
// 4. MINIMALISMO: sem anúncios, promoções, IA embutida ou serviços extras
// ===========================================================================
// Página inicial e nova aba em branco (o mais leve possível)
pref("browser.startup.homepage", "about:blank");
pref("browser.newtabpage.enabled", false);
pref("browser.newtabpage.activity-stream.showSponsored", false);
pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
pref("browser.newtabpage.activity-stream.default.sites", "");
pref("browser.topsites.contile.enabled", false);

// Boas-vindas, "novidades", tour e recomendações
pref("browser.aboutwelcome.enabled", false);
pref("browser.startup.homepage_override.mstone", "ignore");
pref("startup.homepage_welcome_url", "");
pref("startup.homepage_welcome_url.additional", "");
pref("browser.uitour.enabled", false);
pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
pref("browser.preferences.moreFromMozilla", false);
pref("browser.vpn_promo.enabled", false);
pref("browser.promo.focus.enabled", false);
pref("browser.promo.pin.enabled", false);
pref("browser.discovery.enabled", false);
pref("extensions.getAddons.showPane", false);
pref("extensions.htmlaboutaddons.recommendations.enabled", false);
// Não envia periodicamente a lista de extensões instaladas para buscar metadados na AMO.
// (As atualizações das extensões continuam funcionando.)
pref("extensions.getAddons.cache.enabled", false);

// Sugestões patrocinadas e envio do que você digita para o buscador
pref("browser.urlbar.quicksuggest.enabled", false);
pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
pref("browser.search.suggest.enabled", false);
pref("browser.urlbar.suggest.searches", false);

// IA embutida (chatbot na barra lateral, modelos locais, grupos de abas "inteligentes").
// A política GenerativeAI em policies.json desliga o conjunto; estas prefs são o reforço.
pref("browser.ml.enable", false);
pref("browser.ml.chat.enabled", false);
pref("browser.ml.linkPreview.enabled", false);
pref("browser.tabs.groups.smart.enabled", false);

// Conta Firefox / Sync (serviço da Mozilla). Reative com esta pref se quiser usar o Sync.
pref("identity.fxaccounts.enabled", false);

// Interface compacta, sem barra de favoritos por padrão
pref("browser.compactmode.show", true);
pref("browser.uidensity", 1);
pref("browser.toolbars.bookmarks.visibility", "never");

// ===========================================================================
// 5. SEGURANÇA E PRIVACIDADE
// ===========================================================================
// HTTPS em todas as janelas; avisa antes de abrir um site sem HTTPS
pref("dom.security.https_only_mode", true);

// Proteção leve contra fingerprinting. (O modo rigoroso da Proteção contra Rastreamento
// é ligado pela política EnableTrackingProtection: como pref padrão o Firefox o desfaz.)
// (não usamos resistFingerprinting: quebra sites demais para ser padrão)
pref("privacy.fingerprintingProtection", true);
pref("privacy.globalprivacycontrol.enabled", true);

// TLS / certificados
pref("security.tls.enable_0rtt_data", false);
pref("security.ssl.treat_unsafe_negotiation_as_broken", true);
pref("security.cert_pinning.enforcement_level", 2);
pref("browser.xul.error_pages.expert_bad_cert", true);

// Phishing por domínios com caracteres parecidos (IDN homograph)
pref("network.IDN_show_punycode", true);

// JavaScript dentro de PDFs
pref("pdfjs.enableScripting", false);

// Popups de autenticação HTTP disparados por sub-recursos de outros domínios
pref("network.auth.subresource-http-auth-allow", 1);

// Envia só a origem (sem caminho) no Referer entre domínios diferentes
pref("network.http.referer.XOriginTrimmingPolicy", 2);

// WebRTC: não expõe IPs locais/de outras interfaces (vazamento de IP com VPN)
pref("media.peerconnection.ice.default_address_only", true);

// Extensões: sem aviso "permitir extensão de terceiros" silencioso
pref("extensions.postDownloadThirdPartyPrompt", false);

// ===========================================================================
// 6. LEVEZA
// ===========================================================================
// Descarrega abas inativas quando a memória do sistema está acabando
pref("browser.tabs.unloadOnLowMemory", true);

// Grava a sessão em disco a cada 60s em vez de 15s (menos escrita em disco)
pref("browser.sessionstore.interval", 60000);
