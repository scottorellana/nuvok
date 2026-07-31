#!/bin/bash
# Arma el despliegue de nuvok.org en dist/website-deploy/ para la era del
# MURO DE DESCARGA (spec 2026-07-29): el sitio es público; los binarios van a
# R2 y solo se entregan vía el Worker (store-worker/) contra clave de compra.
#
#   site/       → Cloudflare Pages (html/css/js/íconos + version.json público)
#   r2-upload/  → bucket R2 'nuvok-releases': binarios + releases.json
#                 (el manifiesto que el Worker sirve en /api/downloads)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(grep -m1 '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')
APK=build/app/outputs/flutter-apk/app-release.apk
DMG=dist/Nuvok.dmg
OUT=dist/website-deploy
APK_NAME="nuvok-android-v$VERSION.apk"
DMG_NAME="Nuvok-macOS-v$VERSION.dmg"

[ -f "$APK" ] || { echo "Falta $APK — corre scripts/build_android_release_signed.sh"; exit 1; }
[ -f "$DMG" ] || { echo "Falta $DMG — corre scripts/package_macos.sh"; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/site" "$OUT/r2-upload"

# ── Sitio estático (Pages) ──
cp website/index.html website/descargas.html website/styles.css \
   website/i18n.js website/app.js "$OUT/site/"
cp -R website/icons "$OUT/site/"

# ── Binarios (R2) — hardlink para no duplicar en disco ──
ln "$APK" "$OUT/r2-upload/$APK_NAME"
ln "$DMG" "$OUT/r2-upload/$DMG_NAME"

APK_SHA=$(shasum -a 256 "$APK" | awk '{print $1}')
APK_SIZE=$(stat -f %z "$APK")
DMG_SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
DMG_SIZE=$(stat -f %z "$DMG")

# ── releases.json: el manifiesto del Worker (formato de store-worker) ──
python3 - "$OUT/r2-upload/releases.json" "$VERSION" \
  "$APK_NAME" "$APK_SHA" "$APK_SIZE" "$DMG_NAME" "$DMG_SHA" "$DMG_SIZE" <<'PYEOF'
import json, sys
dest, version, apk_n, apk_sha, apk_sz, dmg_n, dmg_sha, dmg_sz = sys.argv[1:9]
json.dump({
    'version': version,
    'files': [
        {'os': 'android', 'name': apk_n, 'bytes': int(apk_sz), 'sha256': apk_sha},
        {'os': 'macos',   'name': dmg_n, 'bytes': int(dmg_sz), 'sha256': dmg_sha},
    ],
}, open(dest, 'w'), indent=2)
print('releases.json (manifiesto del Worker) listo')
PYEOF

# ── version.json público: anuncia la versión al UpdateService de la app.
#    Las URLs apuntan al Worker (/api/dl/...), que exige la clave de compra;
#    sin clave la app muestra su mensaje honesto (Fase 2 del spec). ──
python3 - "$OUT/site/version.json" "$VERSION" \
  "$APK_NAME" "$APK_SHA" "$APK_SIZE" "$DMG_NAME" "$DMG_SHA" "$DMG_SIZE" <<'PYEOF'
import json, sys
dest, version, apk_n, apk_sha, apk_sz, dmg_n, dmg_sha, dmg_sz = sys.argv[1:9]
d = json.load(open('website/version.json'))
d['version'] = version
d['platforms']['android'].update(
    url=f'https://nuvok.org/api/dl/{apk_n}', sha256=apk_sha, sizeBytes=int(apk_sz))
d['platforms']['macos'].update(
    url=f'https://nuvok.org/api/dl/{dmg_n}', sha256=dmg_sha, sizeBytes=int(dmg_sz))
json.dump(d, open(dest, 'w'), indent=2, ensure_ascii=False)
print('version.json publico listo (v' + version + ')')
PYEOF

echo ""
echo "==> LISTO (v$VERSION)."
echo "   site/      → $(du -sh "$OUT/site" | awk '{print $1}')  npx wrangler pages deploy $OUT/site --project-name=nuvok"
echo "   r2-upload/ → $(du -sh "$OUT/r2-upload" | awk '{print $1}')"
for f in "$APK_NAME" "$DMG_NAME" releases.json; do
  echo "                npx wrangler r2 object put nuvok-releases/$f --file=$OUT/r2-upload/$f"
done
echo ""
echo "Después: wrangler deploy en store-worker/ (ver su wrangler.toml)."