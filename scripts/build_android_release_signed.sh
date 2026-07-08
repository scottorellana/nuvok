#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE="$HOME/.prepper-pad/signing/prepper-pad-release.p12"
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
  unset PREPPER_PAD_KEYSTORE PREPPER_PAD_KEY_ALIAS PREPPER_PAD_STORE_PASSWORD PREPPER_PAD_KEY_PASSWORD
  unset STORE_PASSWORD KEY_PASSWORD
}
trap cleanup EXIT

export PREPPER_PAD_KEYSTORE="$KEYSTORE"
export PREPPER_PAD_KEY_ALIAS="$KEY_ALIAS"
export PREPPER_PAD_STORE_PASSWORD="$STORE_PASSWORD"
export PREPPER_PAD_KEY_PASSWORD="$KEY_PASSWORD"

cd "$ROOT"
flutter build apk --release --android-skip-build-dependency-validation
