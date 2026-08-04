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

# Variantes de ISA que viajan en el APK. Cubren desde un Cortex-A53 sin
# producto escalar (gama baja, todavía muy vivo donde se va la luz) hasta i8mm.
# Las armv9.* se descartan a propósito: aportan poco sobre armv8.6 para
# inferencia Q4_K y son 4 MB cada una. Un teléfono ARMv9 cae en armv8.6, que es
# lo mejor que hay disponible — el despacho elige el mayor que soporta.
KEEP_VARIANTS="android_armv8.0_1 android_armv8.2_1 android_armv8.2_2 android_armv8.6_1 x64 sse42 haswell"

build_abi() {
  local abi="$1"
  local build="$WORK/ppllm-android-$abi"
  # Variantes también en x86_64 aunque solo sea el emulador: así el camino de
  # carga dinámica que se prueba ahí es EL MISMO que corre en un teléfono. Un
  # emulador que ejercita otro código no prueba nada.
  local variants=ON
  rm -rf "$build"
  cmake -S "$REPO_DIR/native/pp_llm" -B "$build" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" \
    -DANDROID_PLATFORM="android-$MIN_API" \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_OPENMP=OFF \
    -DPPLLM_CPU_VARIANTS=$variants \
    -DLLAMA_DIR="$LLAMA_DIR" >/dev/null
  cmake --build "$build" --config Release -j"$(sysctl -n hw.ncpu)" >/dev/null

  # Con variantes de CPU el motor ya no es un .so único: hay libggml-base,
  # libllama, libppllm y una librería de CPU por nivel de ISA. Todas tienen que
  # viajar en jniLibs; Android las extrae juntas y ggml elige la mejor al
  # arrancar (ver ppllm_set_backend_dir).
  mkdir -p "$JNI/$abi"
  rm -f "$JNI/$abi"/libggml*.so "$JNI/$abi/libllama.so" "$JNI/$abi/libppllm.so"
  local n=0
  while IFS= read -r so; do
    cp "$so" "$JNI/$abi/$(basename "$so")"
    n=$((n + 1))
  done < <(find "$build" -maxdepth 2 -name "lib*.so" -type f)

  # Tirar las variantes que no viajan (ver KEEP_VARIANTS).
  if [ "$variants" = "ON" ]; then
    for so in "$JNI/$abi"/libggml-cpu-*.so; do
      local name
      name=$(basename "$so" .so); name=${name#libggml-cpu-}
      case " $KEEP_VARIANTS " in
        *" $name "*) ;;
        *) rm -f "$so" ;;
      esac
    done
    # Sin backend de CPU no hay inferencia posible: fallar aquí y no en el
    # teléfono de alguien.
    ls "$JNI/$abi"/libggml-cpu*.so >/dev/null 2>&1 || {
      echo "ERROR: no quedó ninguna variante de CPU para $abi"; exit 1; }
  fi
  [ -f "$JNI/$abi/libppllm.so" ] || { echo "ERROR: falta libppllm.so"; exit 1; }

  # Quitar la información de depuración: son decenas de MB por librería que
  # viajarían en el teléfono de cada usuario sin servir para nada.
  local strip
  strip=$(ls "$NDK"/toolchains/llvm/prebuilt/*/bin/llvm-strip 2>/dev/null | head -1)
  if [ -n "$strip" ]; then
    for so in "$JNI/$abi"/lib*.so; do "$strip" --strip-unneeded "$so" 2>/dev/null || true; done
  fi

  echo "listo: $JNI/$abi/ — $n librerías ($(du -sh "$JNI/$abi" | cut -f1))"
  ls "$JNI/$abi" | sed 's/^/    /'
}

build_abi arm64-v8a
build_abi x86_64
