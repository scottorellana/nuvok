#!/bin/bash
# Nuvok desde el código en UN comando — el camino gratis y siempre
# disponible (GPL v3). Deja el repo listo para `flutter run`.
#
#   git clone --depth 1 https://github.com/scottorellana/nuvok.git
#   cd nuvok && ./scripts/bootstrap.sh
#
# macOS: compila también los motores nativos (IA local con Metal + zstd).
# Linux: prepara la app Flutter; la IA usa un `llama-server` del sistema.
# Android: tras el bootstrap, `flutter build apk` (el APK usa los .so ya
#          incluidos en el repo). iPhone: pasos en README.md.
set -euo pipefail
cd "$(dirname "$0")/.."

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

command -v flutter >/dev/null || {
  echo "Flutter no está instalado. Instálalo primero:"
  echo "  https://docs.flutter.dev/get-started/install"
  exit 1
}

say "Dependencias de Dart"
flutter pub get

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  command -v cmake >/dev/null || {
    echo "cmake es necesario para los motores nativos."
    echo "  Con Homebrew:  brew install cmake"
    echo "  Sin Homebrew:  pip3 install --user cmake  (y añade"
    echo "  ~/Library/Python/*/bin a tu PATH)"
    exit 1
  }
  # llama.cpp: el motor de IA se compila desde su código. Si ya tienes un
  # checkout, expórtalo en LLAMA_DIR; si no, se clona superficial aquí.
  export LLAMA_DIR="${LLAMA_DIR:-$HOME/development/llama.cpp}"
  if [ ! -d "$LLAMA_DIR" ]; then
    say "Clonando llama.cpp (superficial) en $LLAMA_DIR"
    git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"
  fi
  say "Motores nativos (zstd + llama-server) — tarda unos minutos la primera vez"
  ./scripts/build_native_macos.sh
  say "Motor de IA embebido (libppllm, Metal)"
  ./scripts/build_llm_macos.sh
elif [ "$OS" = "Linux" ]; then
  say "Linux: la app compila con Flutter directamente"
  echo "La IA local en Linux usa un binario llama-server del sistema:"
  echo "  compílalo desde https://github.com/ggml-org/llama.cpp o instala"
  echo "  el paquete de tu distro; sin él, la app funciona y lo dice honesto."
fi

if [ "${NUVOK_SKIP_TESTS:-0}" != "1" ]; then
  say "Suite de verificación (≈1 min; NUVOK_SKIP_TESTS=1 para saltarla)"
  flutter test
fi

say "Listo. Para correr Nuvok:"
case "$OS" in
  Darwin) echo "  flutter run -d macos      # escritorio"
          echo "  flutter build apk         # instalador Android"
          echo "  # iPhone: sección 'iPhone' del README.md" ;;
  Linux)  echo "  flutter run -d linux" ;;
esac
