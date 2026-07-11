#!/bin/bash
# Arma el sitio de producción de nuvok.org en dist/website-deploy/, separado
# en dos carpetas porque van a servicios distintos:
#   site/       → Cloudflare Pages (archivos chicos: html/css/js/version.json)
#   downloads/  → Cloudflare R2      (los 2 binarios de 1.6 GB)
# Los enlaces de descarga y version.json apuntan a https://downloads.nuvok.org
# (absolutos) para que NO haga falta ninguna regla de redirección.
set -euo pipefail
cd "$(dirname "$0")/.."

APK=dist/prepper-pad-full-v0.5.0.apk
DMG=dist/Nuvok.dmg
OUT=dist/website-deploy
DL_BASE="https://downloads.nuvok.org"
APK_NAME=nuvok-android-v0.5.0.apk
DMG_NAME=Nuvok-macOS-v0.5.0.dmg

[ -f "$APK" ] || { echo "Falta $APK — corre primero build_android_release_signed.sh"; exit 1; }
[ -f "$DMG" ] || { echo "Falta $DMG — corre primero package_macos.sh"; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/site" "$OUT/downloads"

# ── Archivos chicos del sitio ── (Pages)
cp website/index.html website/styles.css website/i18n.js website/app.js "$OUT/site/"
# Iconos/favicon/logo oficial de Nuvok (referenciados desde index.html).
cp -R website/icons "$OUT/site/"

# ── Binarios ── (R2), hardlink para no duplicar 3.2 GB en disco
ln "$APK" "$OUT/downloads/$APK_NAME"
ln "$DMG" "$OUT/downloads/$DMG_NAME"

# ── Reescribir enlaces del sitio a URLs absolutas de descargas ──
sed -i '' "s|/downloads/$APK_NAME|$DL_BASE/$APK_NAME|g; s|/downloads/$DMG_NAME|$DL_BASE/$DMG_NAME|g" "$OUT/site/index.html"

# ── version.json con SHAs REALES y URLs absolutas ──
APK_SHA=$(shasum -a 256 "$APK" | awk '{print $1}')
APK_SIZE=$(stat -f %z "$APK")
DMG_SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
DMG_SIZE=$(stat -f %z "$DMG")

python3 - "$OUT/site/version.json" "$DL_BASE" "$APK_NAME" "$APK_SHA" "$APK_SIZE" "$DMG_NAME" "$DMG_SHA" "$DMG_SIZE" <<'PYEOF'
import json, sys
dest, base, apk_name, apk_sha, apk_size, dmg_name, dmg_sha, dmg_size = sys.argv[1:9]
d = json.load(open('website/version.json'))
d['platforms']['android'].update(
    url=f'{base}/{apk_name}', sha256=apk_sha, sizeBytes=int(apk_size))
d['platforms']['macos'].update(
    url=f'{base}/{dmg_name}', sha256=dmg_sha, sizeBytes=int(dmg_size))
json.dump(d, open(dest, 'w'), indent=2, ensure_ascii=False)
print('version.json listo con SHAs reales y URLs a', base)
PYEOF

echo ""
echo "==> LISTO."
echo "   $OUT/site/       → subir a Cloudflare Pages   ($(du -sh "$OUT/site" | awk '{print $1}'))"
echo "   $OUT/downloads/  → subir a Cloudflare R2      ($(du -sh "$OUT/downloads" | awk '{print $1}'))"
echo ""
echo "Sigue website/DEPLOY.md paso a paso."
