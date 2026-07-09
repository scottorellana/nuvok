#!/bin/bash
# Builds libppllm.so (embedded llama.cpp engine, CPU/NEON) for Android and
# drops it into android/app/src/main/jniLibs/<abi>/ — same packaging as
# libzstd.so. arm64-v8a is the real target (phones/tablets); x86_64 exists
# for the emulator. 32-bit ARM is skipped: a local LLM on a ≤3GB 32-bit
# device is not a real scenario and llama.cpp barely fits there.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$REPO_DIR/native/work"
JNI="$REPO_DIR/android/app/src/main/jniLibs"
LLAMA_DIR="${LLAMA_DIR:-$HOME/development/llama.cpp}"
NDK="${ANDROID_NDK:-$(ls -d "$HOME/Library/Android/sdk/ndk/"* 2>/dev/null | sort -V | tail -1)}"
MIN_API=26

command -v cmake >/dev/null || { echo "cmake no encontrado"; exit 1; }
[ -d "$LLAMA_DIR" ] || { echo "llama.cpp no está en $LLAMA_DIR"; exit 1; }
[ -n "$NDK" ] && [ -d "$NDK" ] || { echo "NDK no encontrado"; exit 1; }
echo "NDK: $NDK"

build_abi() {
  local abi="$1"
  local build="$WORK/ppllm-android-$abi"
  rm -rf "$build"
  cmake -S "$REPO_DIR/native/pp_llm" -B "$build" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" \
    -DANDROID_PLATFORM="android-$MIN_API" \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_OPENMP=OFF \
    -DLLAMA_DIR="$LLAMA_DIR" >/dev/null
  cmake --build "$build" --config Release -j"$(sysctl -n hw.ncpu)" >/dev/null
  mkdir -p "$JNI/$abi"
  cp "$build/libppllm.so" "$JNI/$abi/libppllm.so"
  echo "listo: $JNI/$abi/libppllm.so ($(du -h "$JNI/$abi/libppllm.so" | cut -f1))"
}

build_abi arm64-v8a
build_abi x86_64
