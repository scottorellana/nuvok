#!/bin/bash
# Builds the native engines Prepper Pad embeds on macOS:
#   - libzstd.1.dylib  (ZIM cluster decompression)
#   - llama-server     (local AI, static build with embedded Metal shaders)
# Outputs to native/out/macos/. Requires Xcode and cmake.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_DIR/native/out/macos"
WORK="$REPO_DIR/native/work"
mkdir -p "$OUT" "$WORK"

command -v cmake >/dev/null || {
  echo "cmake no encontrado. Instálalo con: pip3 install --user cmake"
  echo "y agrega ~/Library/Python/3.9/bin a tu PATH."
  exit 1
}

# --- zstd -------------------------------------------------------------------
if [ ! -f "$OUT/libzstd.1.dylib" ]; then
  echo "==> Compilando zstd…"
  if [ ! -d "$WORK/zstd" ]; then
    git clone --depth 1 --branch v1.5.7 https://github.com/facebook/zstd.git "$WORK/zstd"
  fi
  make -C "$WORK/zstd" lib-release -j"$(sysctl -n hw.ncpu)"
  cp "$WORK/zstd/lib/libzstd.1."*.dylib "$OUT/libzstd.1.dylib"
  # The dylib install name must be @rpath-relative for app bundling.
  install_name_tool -id "@rpath/libzstd.1.dylib" "$OUT/libzstd.1.dylib"
fi
echo "zstd listo: $OUT/libzstd.1.dylib"

# --- llama.cpp (llama-server) -------------------------------------------------
if [ ! -f "$OUT/llama-server" ]; then
  echo "==> Compilando llama-server (esto tarda varios minutos)…"
  if [ ! -d "$WORK/llama.cpp" ]; then
    git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$WORK/llama.cpp"
  fi
  cmake -S "$WORK/llama.cpp" -B "$WORK/llama.cpp/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLAMA_CURL=OFF \
    -DGGML_METAL_EMBED_LIBRARY=ON
  cmake --build "$WORK/llama.cpp/build" --target llama-server -j"$(sysctl -n hw.ncpu)"
  cp "$WORK/llama.cpp/build/bin/llama-server" "$OUT/llama-server"
fi
echo "llama-server listo: $OUT/llama-server"
echo "==> Motores nativos completos."
