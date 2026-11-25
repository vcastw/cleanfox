#!/usr/bin/env bash
# Ajustes do app Android (Fenix): telemetria desligada na compilação, nome, ID e arte
# próprios. Chamado por scripts/prepare.sh. Cada edição falha se o trecho esperado não
# existir mais — assim uma versão nova do Firefox nunca passa "meio aplicada".
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"
need python3

FENIX="$SRC_DIR/mobile/android/fenix/app"
[ -f "$FENIX/build.gradle" ] || die "Fenix não encontrado em $FENIX"

log "Fenix: telemetria, ID e nome do app"
python3 - "$FENIX" <<'PY'
import sys
from pathlib import Path

fenix = Path(sys.argv[1])


def edit(path, replacements):
    text = path.read_text()
    for old, new, count in replacements:
        found = text.count(old)
        if found != count:
            sys.exit(f"erro: {path}: esperado {count}x {old!r}, encontrado {found}x")
        text = text.replace(old, new)
    path.write_text(text)


gradle = fenix / "build.gradle"
text = gradle.read_text()

# 1. Telemetria (Glean), marketing (Adjust), relatório de falhas (Sentry) e Play Integrity:
#    o Fenix decide tudo por estas duas flags; nos builds de debug já são false.
start = text.index("android.defaultConfig.with {")
end = text.index("android.buildTypes.debug.with {")
block = text[start:end]
for flag in ("CRASH_REPORTING", "TELEMETRY"):
    old = f"buildConfigField 'boolean', '{flag}', 'true'"
    if block.count(old) != 1:
        sys.exit(f"erro: flag {flag} não encontrada em build.gradle")
    block = block.replace(old, f"buildConfigField 'boolean', '{flag}', 'false'")
text = text[:start] + block + text[end:]

# 2. ID do app: io.github.coldfox (instala lado a lado com o Firefox, sem sharedUserId dele).
start = text.index("release releaseTemplate >> {")
end = text.index("benchmark releaseTemplate >> {")
block = text[start:end]
for old, new in (
    ('applicationIdSuffix ".firefox"', 'applicationIdSuffix ".coldfox"'),
    ('"sharedUserId": "org.mozilla.firefox.sharedID"', '"sharedUserId": "io.github.coldfox.sharedID"'),
):
    if block.count(old) != 1:
        sys.exit(f"erro: {old!r} não encontrado no build type release")
    block = block.replace(old, new)
text = text[:start] + block + text[end:]
gradle.write_text(text)
edit(gradle, [('applicationId "org.mozilla"', 'applicationId "io.github"', 1)])

# 3. Nome do app.
edit(
    fenix / "src/release/res/values/static_strings.xml",
    [('<string name="app_name" translatable="false">Firefox</string>',
      '<string name="app_name" translatable="false">ColdFox</string>', 1)],
)
PY

log "Fenix: padrões de privacidade, buscador, Safe Browsing e extensões de fábrica"
python3 - "$SRC_DIR/mobile/android" "$ROOT/android" <<'PY'
import shutil
import sys
from pathlib import Path

android, ours = Path(sys.argv[1]), Path(sys.argv[2])
fenix = android / "fenix/app/src/main"
ac = android / "android-components/components"


def edit(path, replacements):
    text = path.read_text()
    for old, new, count in replacements:
        found = text.count(old)
        if found != count:
            sys.exit(f"erro: {path}: esperado {count}x {old!r}, encontrado {found}x")
        text = text.replace(old, new)
    path.write_text(text)


I = "\n            "
# Padrões das Configurações (o usuário pode mudar todos).
edit(fenix / "java/org/mozilla/fenix/utils/Settings.kt", [
    # Chave "Telemetria" desligada (o envio já não é compilado); estudos e ping diário
    # herdam este valor.
    ("R.string.pref_key_telemetry)," + I + "default = true,",
     "R.string.pref_key_telemetry)," + I + "default = false,", 1),
    # Atalhos patrocinados, histórias do Pocket e sugestões do Firefox Suggest.
    ("R.string.pref_key_enable_contile)," + I + "default = true,",
     "R.string.pref_key_enable_contile)," + I + "default = false,", 1),
    ("defaultValue = { homescreenSections[HomeScreenSection.POCKET] == true },",
     "defaultValue = { false },", 1),
    ("defaultValue = { homescreenSections[HomeScreenSection.POCKET_SPONSORED_STORIES] == true },",
     "defaultValue = { false },", 1),
    ("defaultValue = { FxNimbus.features.fxSuggest.value().enabled },",
     "defaultValue = { false },", 1),
    # Não envia o que é digitado ao buscador enquanto se digita.
    ("R.string.pref_key_show_search_suggestions)," + I + "default = true,",
     "R.string.pref_key_show_search_suggestions)," + I + "default = false,", 1),
    # Proteção contra rastreamento rigorosa, HTTPS em todas as abas e GPC, como no desktop.
    ("R.string.pref_key_tracking_protection_standard_option)," + I + "true,",
     "R.string.pref_key_tracking_protection_standard_option)," + I + "false,", 1),
    ("R.string.pref_key_tracking_protection_strict_default)," + I + "false,",
     "R.string.pref_key_tracking_protection_strict_default)," + I + "true,", 1),
    ("R.string.pref_key_https_only)," + I + "default = false,",
     "R.string.pref_key_https_only)," + I + "default = true,", 1),
    ("R.string.pref_key_privacy_enable_global_privacy_control)," + I + "false,",
     "R.string.pref_key_privacy_enable_global_privacy_control)," + I + "true,", 1),
])
edit(fenix / "res/xml/tracking_protection_preferences.xml", [
    ('android:defaultValue="true"\n        android:dependency="@string/pref_key_tracking_protection"\n'
     '        android:key="@string/pref_key_tracking_protection_standard_option"',
     'android:defaultValue="false"\n        android:dependency="@string/pref_key_tracking_protection"\n'
     '        android:key="@string/pref_key_tracking_protection_standard_option"', 1),
    ('android:defaultValue="false"\n        android:dependency="@string/pref_key_tracking_protection"\n'
     '        android:key="@string/pref_key_tracking_protection_strict_default"',
     'android:defaultValue="true"\n        android:dependency="@string/pref_key_tracking_protection"\n'
     '        android:key="@string/pref_key_tracking_protection_strict_default"', 1),
])

# Sem apresentação inicial (como no desktop): ela traz consentimentos de telemetria e
# marketing da Mozilla e os Termos de Uso do Firefox, que não se aplicam ao ColdFox.
edit(fenix / "java/org/mozilla/fenix/utils/Settings.kt", [
    ("val shouldShowByDefaultConditions = featureEnabled && !hasUserBeenOnboarded",
     "val shouldShowByDefaultConditions = false // ColdFox: sem apresentação inicial", 1),
])
edit(fenix / "java/org/mozilla/fenix/termsofuse/store/TermsOfUsePromptRepository.kt", [
    ("override fun canShowTermsOfUsePrompt(): Boolean =\n        !settings.hasAcceptedTermsOfService &&",
     "override fun canShowTermsOfUsePrompt(): Boolean =\n        false && // ColdFox: Termos de Uso da Mozilla não se aplicam\n"
     "            !settings.hasAcceptedTermsOfService &&", 1),
])

# Safe Browsing do Google desligado (o motor o forçava ligado na inicialização).
edit(ac / "browser/engine-gecko/src/main/java/mozilla/components/browser/engine/gecko/GeckoEngine.kt", [
    ("override var safeBrowsingPolicy: Array<SafeBrowsingPolicy> = arrayOf(SafeBrowsingPolicy.RECOMMENDED)",
     "override var safeBrowsingPolicy: Array<SafeBrowsingPolicy> = arrayOf(SafeBrowsingPolicy.NONE)", 1),
    ("this.safeBrowsingPolicy = arrayOf(SafeBrowsingPolicy.RECOMMENDED)",
     "this.safeBrowsingPolicy = arrayOf(SafeBrowsingPolicy.NONE)", 1),
])

# Buscador padrão: DuckDuckGo quando disponível na região (a escolha do usuário prevalece).
edit(ac / "feature/search/src/main/java/mozilla/components/feature/search/middleware/SearchMiddleware.kt", [
    ("regionDefaultSearchEngineId = regionBundle.defaultSearchEngineId,",
     'regionDefaultSearchEngineId = filteredRegionSearchEngines.firstOrNull { it.id == "ddg" }?.id\n'
     "                ?: regionBundle.defaultSearchEngineId,", 1),
])

# Extensões de fábrica: gancho que aprova sem diálogo só o que o app instalou.
edit(ac / "support/webextensions/src/main/java/mozilla/components/support/webextensions/WebExtensionSupport.kt", [
    ("object WebExtensionSupport {\n",
     "object WebExtensionSupport {\n"
     "    /** ColdFox: aprova sem diálogo instalações iniciadas pelo próprio app; null = perguntar. */\n"
     "    @Volatile\n"
     "    var installPermissionInterceptor: ((WebExtension) -> PermissionPromptResponse?)? = null\n\n", 1),
    ("                    onConfirm: (PermissionPromptResponse) -> Unit,\n                ) {\n"
     "                    store.dispatch(\n"
     "                        WebExtensionAction.UpdatePromptRequestWebExtensionAction(\n"
     "                            WebExtensionPromptRequest.AfterInstallation.Permissions.Required(",
     "                    onConfirm: (PermissionPromptResponse) -> Unit,\n                ) {\n"
     "                    installPermissionInterceptor?.invoke(extension)?.let {\n"
     "                        onConfirm(it)\n"
     "                        return\n"
     "                    }\n"
     "                    store.dispatch(\n"
     "                        WebExtensionAction.UpdatePromptRequestWebExtensionAction(\n"
     "                            WebExtensionPromptRequest.AfterInstallation.Permissions.Required(", 1),
])
edit(fenix / "java/org/mozilla/fenix/FenixApplication.kt", [
    ("                    subscribeForNewAddonsIfNeeded(components.supportedAddonsChecker, extensions)\n",
     "                    subscribeForNewAddonsIfNeeded(components.supportedAddonsChecker, extensions)\n"
     "                    org.mozilla.fenix.coldfox.DefaultAddons.installIfNeeded(\n"
     "                        this,\n"
     "                        components.addonManager,\n"
     "                        extensions,\n"
     "                    )\n", 1),
])
dest = fenix / "java/org/mozilla/fenix/coldfox"
dest.mkdir(parents=True, exist_ok=True)
shutil.copy(ours / "DefaultAddons.kt", dest / "DefaultAddons.kt")
PY

log "Fenix: arte do ColdFox"
RES="$FENIX/src/release/res"
# Toda imagem de marca da variante release precisa ter substituta nossa; se uma versão
# nova do Firefox trouxer arte que não cobrimos, paramos aqui em vez de distribuí-la.
missing=0
while IFS= read -r -d '' f; do
  rel="${f#"$RES"/}"
  if [ ! -f "$ROOT/branding/android/res/$rel" ]; then
    echo "  sem substituto para: $rel" >&2
    missing=1
  fi
done < <(find "$RES" -type f \( -name '*.webp' -o -name '*.png' -o -path '*/drawable/*.xml' \) -print0)
[ "$missing" = 0 ] || die "arte da Mozilla sem substituto (atualize tools/gen-branding.py)"
cp -r "$ROOT/branding/android/res/." "$RES/"
