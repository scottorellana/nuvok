#!/bin/bash
# Arma el sitio de producción de nuvok.org en dist/website-deploy/:
#   sitio estático + version.json (con SHAs REALES de los binarios de dist/)
#   + los binarios con sus nombres públicos (hardlinks: no duplica 3.4 GB).
# Salida lista para subir tal cual a cualquier hosting (ver website/DEPLOY.md).
set -euo pipefail
cd "$(dirname "$0")/.."

APK=dist/prepper-pad-full-v0.5.0.apk
DMG=dist/Nuvok.dmg
OUT=dist/website-deploy

[ -f "$APK" ] || { echo "Falta $APK — corre primero build_android_release_signed.sh"; exit 1; }
[ -f "$DMG" ] || { echo "Falta $DMG — corre primero package_macos.sh"; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/downloads"
cp website/index.html website/styles.css website/i18n.js website/app.js "$OUT/"

ln "$APK" "$OUT/downloads/nuvok-android-v0.5.0.apk"
ln "$DMG" "$OUT/downloads/Nuvok-macOS-v0.5.0.dmg"

APK_SHA=$(shasum -a 256 "$APK" | awk '{print $1}')
APK_SIZE=$(stat -f %z "$APK")
DMG_SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
DMG_SIZE=$(stat -f %z "$DMG")

python3 - "$OUT" "$APK_SHA" "$APK_SIZE" "$DMG_SHA" "$DMG_SIZE" <<'PYEOF'
import json, sys
out, apk_sha, apk_size, dmg_sha, dmg_size = sys.argv[1:6]
d = json.load(open('website/version.json'))
d['platforms']['android']['sha256'] = apk_sha
d['platforms']['android']['sizeBytes'] = int(apk_size)
d['platforms']['macos']['sha256'] = dmg_sha
d['platforms']['macos']['sizeBytes'] = int(dmg_size)
json.dump(d, open(f'{out}/version.json', 'w'), indent=2, ensure_ascii=False)
print('version.json con SHAs reales')
PYEOF

echo "==> Listo: $OUT/"
du -sh "$OUT"
echo "Sube el CONTENIDO de $OUT a nuvok.org (ver website/DEPLOY.md)."
