#!/bin/bash
# Builds the release .app, embeds the native engines, and produces
# dist/PrepperPad.dmg ready to distribute (Hermes-style: download, drag,
# right-click → Open the first time).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NATIVE="$REPO_DIR/native/out/macos"
DIST="$REPO_DIR/dist"

[ -f "$NATIVE/libppllm.dylib" ] && [ -f "$NATIVE/libzstd.1.dylib" ] || {
  echo "Motores nativos no encontrados. Ejecuta scripts/build_native_macos.sh y scripts/build_llm_macos.sh primero."
  exit 1
}

cd "$REPO_DIR"
flutter build macos --release

APP_SRC="$REPO_DIR/build/macos/Build/Products/Release/prepper_pad.app"
[ -d "$APP_SRC" ] || APP_SRC="$REPO_DIR/build/macos/Build/Products/Release/Prepper Pad.app"

mkdir -p "$DIST"
rm -rf "$DIST/Prepper Pad.app" "$DIST/PrepperPad.dmg" "$DIST/dmg-root"
cp -R "$APP_SRC" "$DIST/Prepper Pad.app"

APP="$DIST/Prepper Pad.app"
mkdir -p "$APP/Contents/Frameworks"
# The AI engine is libppllm (llama.cpp in-process, Metal) — the same engine
# the app runs on iPhone and Android.
cp "$NATIVE/libppllm.dylib" "$APP/Contents/Frameworks/"
cp "$NATIVE/libzstd.1.dylib" "$APP/Contents/Frameworks/"

# Ad-hoc signature so macOS Gatekeeper allows right-click → Open.
codesign --force --deep -s - "$APP"

# Build the DMG with an Applications symlink for drag-install.
mkdir -p "$DIST/dmg-root"
cp -R "$APP" "$DIST/dmg-root/"
ln -s /Applications "$DIST/dmg-root/Applications"
hdiutil create -volname "Prepper Pad" -srcfolder "$DIST/dmg-root" \
  -ov -format UDZO "$DIST/PrepperPad.dmg"
rm -rf "$DIST/dmg-root"

echo "==> Listo: $DIST/PrepperPad.dmg"
