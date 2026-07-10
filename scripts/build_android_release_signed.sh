#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE="$HOME/.prepper-pad/signing/prepper-pad-release.p12"
# Keep the historical signing identity so installed Prepper Pad builds can
# upgrade to Nuvok without Android rejecting the package signature.
KEY_ALIAS="prepper-pad-release"
KEYCHAIN_SERVICE="com.prepperpad.android.release-signing"

if [[ ! -f "$KEYSTORE" ]]; then
  echo "FATAL: Release keystore not found at $KEYSTORE" >&2
  exit 1
fi

STORE_PASSWORD="$(security find-generic-password -a store-password -s "$KEYCHAIN_SERVICE" -w)"
KEY_PASSWORD="$(security find-generic-password -a key-password -s "$KEYCHAIN_SERVICE" -w)"

if [[ -z "$STORE_PASSWORD" || -z "$KEY_PASSWORD" ]]; then
  echo "FATAL: Release signing passwords are missing from macOS Keychain service $KEYCHAIN_SERVICE" >&2
  exit 1
fi

cleanup() {
  unset NUVOK_KEYSTORE NUVOK_KEY_ALIAS NUVOK_STORE_PASSWORD NUVOK_KEY_PASSWORD
  unset STORE_PASSWORD KEY_PASSWORD
}
trap cleanup EXIT

export NUVOK_KEYSTORE="$KEYSTORE"
export NUVOK_KEY_ALIAS="$KEY_ALIAS"
export NUVOK_STORE_PASSWORD="$STORE_PASSWORD"
export NUVOK_KEY_PASSWORD="$KEY_PASSWORD"

cd "$ROOT"
flutter build apk --release --android-skip-build-dependency-validation
