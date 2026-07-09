#!/bin/bash
# Builds libppllm.dylib (embedded llama.cpp engine, Metal) for macOS.
# Output: native/out/macos/libppllm.dylib — loaded by Dart FFI.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_DIR/native/out/macos"
WORK="$REPO_DIR/native/work"
LLAMA_DIR="${LLAMA_DIR:-$HOME/development/llama.cpp}"
mkdir -p "$OUT" "$WORK"

command -v cmake >/dev/null || {
  echo "cmake no encontrado (pip3 install --user cmake)"; exit 1;
}
[ -d "$LLAMA_DIR" ] || {
  echo "llama.cpp no encontrado en $LLAMA_DIR (export LLAMA_DIR=...)"; exit 1;
}

BUILD="$WORK/ppllm-macos"
cmake -S "$REPO_DIR/native/pp_llm" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_DIR="$LLAMA_DIR" >/dev/null
cmake --build "$BUILD" --config Release -j"$(sysctl -n hw.ncpu)"

cp "$BUILD/libppllm.dylib" "$OUT/libppllm.dylib"
install_name_tool -id "@rpath/libppllm.dylib" "$OUT/libppllm.dylib"
echo "listo: $OUT/libppllm.dylib"
