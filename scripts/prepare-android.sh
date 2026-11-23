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

# 2. ID do app: io.github.cleanfox (instala lado a lado com o Firefox, sem sharedUserId dele).
start = text.index("release releaseTemplate >> {")
end = text.index("benchmark releaseTemplate >> {")
block = text[start:end]
for old, new in (
    ('applicationIdSuffix ".firefox"', 'applicationIdSuffix ".cleanfox"'),
    ('"sharedUserId": "org.mozilla.firefox.sharedID"', '"sharedUserId": "io.github.cleanfox.sharedID"'),
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
      '<string name="app_name" translatable="false">CleanFox</string>', 1)],
)
PY

log "Fenix: arte do CleanFox"
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
