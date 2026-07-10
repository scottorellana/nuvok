#!/bin/bash
# Builds ppllm (embedded llama.cpp engine, Metal) as an iOS xcframework:
# device arm64 + simulator arm64 → native/out/ios/ppllm.xcframework,
# consumed by the Runner via the local Nuvok_native pod (same pattern as
# zstd). Takes ~10 min: llama.cpp compiles twice.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$REPO_DIR/native/work"
OUT="$REPO_DIR/native/out/ios"
LLAMA_DIR="${LLAMA_DIR:-$HOME/development/llama.cpp}"
MIN_IOS=14.0
mkdir -p "$WORK" "$OUT"

command -v cmake >/dev/null || {
  echo "cmake no encontrado (pip3 install --user cmake)"; exit 1;
}
[ -d "$LLAMA_DIR" ] || {
  echo "llama.cpp no encontrado en $LLAMA_DIR"; exit 1;
}

build_one() {
  # Simulator slice must be arm64+x86_64: Flutter's sim builds pass both
  # ARCHS and CocoaPods refuses an xcframework slice that lacks one.
  local sdk="$1" outdir="$2" archs="$3"
  local build="$WORK/ppllm-ios-$sdk"
  rm -rf "$build"
  cmake -S "$REPO_DIR/native/pp_llm" -B "$build" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$sdk" \
    -DCMAKE_OSX_ARCHITECTURES="$archs" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_DIR="$LLAMA_DIR" >/dev/null
  cmake --build "$build" --config Release -j"$(sysctl -n hw.ncpu)" >/dev/null

  local fw="$outdir/ppllm.framework"
  rm -rf "$fw" && mkdir -p "$fw"
  cp "$build/libppllm.dylib" "$fw/ppllm"
  install_name_tool -id "@rpath/ppllm.framework/ppllm" "$fw/ppllm"
  cat > "$fw/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>ppllm</string>
  <key>CFBundleIdentifier</key><string>org.nuvok.ppllm</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>ppllm</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>$MIN_IOS</string>
</dict>
</plist>
PLIST
}

echo "==> ppllm para iPhone (device)…"
DEV_DIR="$WORK/ppllm-fw-device"; rm -rf "$DEV_DIR"; mkdir -p "$DEV_DIR"
build_one iphoneos "$DEV_DIR" "arm64"

echo "==> ppllm para simulador…"
SIM_DIR="$WORK/ppllm-fw-sim"; rm -rf "$SIM_DIR"; mkdir -p "$SIM_DIR"
build_one iphonesimulator "$SIM_DIR" "arm64;x86_64"

echo "==> Empaquetando xcframework…"
rm -rf "$OUT/ppllm.xcframework"
xcodebuild -create-xcframework \
  -framework "$DEV_DIR/ppllm.framework" \
  -framework "$SIM_DIR/ppllm.framework" \
  -output "$OUT/ppllm.xcframework" >/dev/null
echo "listo: $OUT/ppllm.xcframework"
