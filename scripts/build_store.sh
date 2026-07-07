#!/bin/bash
# Store builds (App Store / Google Play) must NOT embed the multi-GB starter
# library: Play caps the base download (~200MB) and store users download
# content in-app from public mirrors anyway. The direct channel (tablet
# image, .dmg, sideloaded APK) keeps everything embedded.
#
# This script stashes assets/bundled_library/ content, swaps in an empty
# manifest, builds with STORE_BUILD=true, and ALWAYS restores on exit.
#
# Usage: ./scripts/build_store.sh appbundle   (Android .aab para Play)
#        ./scripts/build_store.sh ipa         (iOS para App Store)
set -euo pipefail

TARGET="${1:-appbundle}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$REPO/assets/bundled_library"
STASH="$REPO/native/work/bundled_library_stash"

restore() {
  if [ -d "$STASH" ]; then
    rm -f "$LIB"/*/placeholder.bin 2>/dev/null || true
    rsync -a "$STASH/" "$LIB/"
    rm -rf "$STASH"
    echo "==> Biblioteca embebida restaurada."
  fi
}
trap restore EXIT

if [ -d "$STASH" ]; then
  echo "Stash previo encontrado (build interrumpido); restaurando primero…"
  restore
fi

echo "==> Apartando la biblioteca embebida (solo canal directo)…"
mkdir -p "$STASH"
rsync -a "$LIB/" "$STASH/"
for d in zim maps models; do
  find "$LIB/$d" -type f -delete 2>/dev/null || true
  # Flutter rejects asset directories with no visible files.
  printf '' > "$LIB/$d/placeholder.bin"
done
cat > "$LIB/manifest.json" <<'JSON'
{
  "version": 1,
  "description": "Build de tienda: el contenido se descarga desde la app.",
  "entries": []
}
JSON

echo "==> Compilando build de tienda ($TARGET)…"
flutter build "$TARGET" --release --dart-define=STORE_BUILD=true

case "$TARGET" in
  appbundle)
    ls -lh "$REPO/build/app/outputs/bundle/release/app-release.aab"
    ;;
  ipa)
    ls -lh "$REPO/build/ios/ipa/"*.ipa 2>/dev/null || true
    ;;
esac
