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

# ─────────────────────────────────────────────────────────────────────────────
# PENDIENTE (necesita un Android físico para validarse): el .so que se envía va
# sin instrucciones de producto escalar.
#
# Verificado sobre el binario versionado, no en teoría:
#   llvm-objdump -d jniLibs/arm64-v8a/libppllm.so
#     sdot 0 · smmla 0 · udot 0 · usdot 0 · fmla 1859
#
# Este script no pasa ningún -march, así que __ARM_FEATURE_DOTPROD no se define
# y ggml compila el camino de respaldo: emula el producto escalar con
# vmull_s8 + vpaddlq en vez de una sola instrucción sdot. Y ese es exactamente
# el kernel que usa Gemma 4 (ggml_vec_dot_q4_K_q8_K). Como en Android la IA
# corre en CPU pura (nGpuLayers = 0), TODOS los tokens de TODOS los teléfonos
# pasan por ahí. Se paga en ciclos, o sea en batería, que en un apagón es la
# linterna y el SOS.
#
# NO se arregla con -march=armv8.2-a+dotprod: eso mataría con SIGILL a los
# teléfonos armv8.0 (Cortex-A53), que son justo los de gama baja del público de
# Nuvok. La vía correcta es el despacho en runtime de llama.cpp:
#
#   -DBUILD_SHARED_LIBS=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON
#
# que compila las variantes android_armv8.0_1 / armv8.2_1 (DOTPROD) /
# armv8.6_1 (MATMUL_INT8) … y elige la mejor al arrancar
# (llama.cpp ggml/src/CMakeLists.txt, sección Android).
#
# Por qué no está activado ya: obliga a abandonar el .so único y estático que
# empaqueta Nuvok (native/pp_llm/CMakeLists.txt:17 fija BUILD_SHARED_LIBS OFF)
# y a distribuir libggml, libllama y cada variante de CPU por separado. Si esa
# carga dinámica falla en algún dispositivo, la IA no arranca en NINGÚN
# Android. No se cambia sin un teléfono real donde comprobar que carga, que
# elige la variante correcta y que responde.
