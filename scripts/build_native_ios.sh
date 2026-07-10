#!/bin/bash
# Builds zstd as a dynamic framework for iOS (device arm64 + simulator arm64)
# and packages it as native/out/ios/zstd.xcframework, consumed by the Runner
# via the local Nuvok_native pod. Dynamic (not static) because Dart FFI
# resolves symbols at runtime and the static linker would dead-strip them;
# a bare .dylib is not allowed on iOS, so it ships wrapped in a .framework.
# liblzma is NOT built: Apple's SDK provides it on iOS.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$REPO_DIR/native/work"
OUT="$REPO_DIR/native/out/ios"
ZSTD_VERSION=v1.5.7
MIN_IOS=14.0

command -v cmake >/dev/null || {
  echo "cmake no encontrado. Instálalo con: pip3 install --user cmake"
  exit 1
}

if [ ! -d "$WORK/zstd" ]; then
  git clone --depth 1 --branch "$ZSTD_VERSION" \
    https://github.com/facebook/zstd.git "$WORK/zstd"
fi

build_one() {
  local sdk="$1" outdir="$2" archs="$3"
  local build="$WORK/zstd-ios-$sdk"
  rm -rf "$build"
  cmake -S "$WORK/zstd/build/cmake" -B "$build" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$sdk" \
    -DCMAKE_OSX_ARCHITECTURES="$archs" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
    -DCMAKE_BUILD_TYPE=Release \
    -DZSTD_BUILD_PROGRAMS=OFF \
    -DZSTD_BUILD_STATIC=OFF \
    -DZSTD_BUILD_SHARED=ON \
    -DZSTD_BUILD_TESTS=OFF \
    -DZSTD_MULTITHREAD_SUPPORT=OFF >/dev/null
  cmake --build "$build" --config Release -j"$(sysctl -n hw.ncpu)" >/dev/null

  # Wrap the dylib in a minimal framework (required packaging on iOS).
  local fw="$outdir/zstd.framework"
  rm -rf "$fw" && mkdir -p "$fw"
  cp "$build/lib/libzstd.1"*.dylib "$fw/zstd" 2>/dev/null \
    || cp "$build/lib/libzstd.dylib" "$fw/zstd"
  install_name_tool -id "@rpath/zstd.framework/zstd" "$fw/zstd"
  cat > "$fw/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>zstd</string>
	<key>CFBundleIdentifier</key><string>org.zstd.zstd</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>zstd</string>
	<key>CFBundlePackageType</key><string>FMWK</string>
	<key>CFBundleShortVersionString</key><string>1.5.7</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>MinimumOSVersion</key><string>$MIN_IOS</string>
</dict>
</plist>
PLIST
}

echo "==> zstd para iPhone (arm64)…"
build_one iphoneos "$WORK/fw-device" "arm64"
# Simulator slice is FAT (arm64+x86_64): Xcode sets ARCHS to both for
# simulator builds and CocoaPods' slice selector requires every arch present.
echo "==> zstd para simulador (arm64+x86_64)…"
build_one iphonesimulator "$WORK/fw-sim" "arm64;x86_64"

echo "==> Empaquetando xcframework…"
rm -rf "$OUT/zstd.xcframework" && mkdir -p "$OUT"
xcodebuild -create-xcframework \
  -framework "$WORK/fw-device/zstd.framework" \
  -framework "$WORK/fw-sim/zstd.framework" \
  -output "$OUT/zstd.xcframework" >/dev/null

echo "Listo: $OUT/zstd.xcframework"
