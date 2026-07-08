#!/bin/bash
# build_country.sh — Build a country-specific Prepper Pad installer.
#
# Usage: ./scripts/build_country.sh <country-id> [--no-map-download]
#
# Reads the profile from scripts/country-profiles.yaml, prepares the
# bundled assets for that country (map + language), and builds the APK.
#
# The resulting APK is placed at:
#   dist/prepper-pad-v<version>-<country>.apk
#
# If the country's .pmtiles is not already in ~/PrepperPad/maps/ or
# assets/bundled_library/maps/, the script tries to download it from
# the Protomaps daily builds using the pmtiles CLI tool.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

COUNTRY="${1:?Usage: build_country.sh <country-id> [flags]}"
SKIP_DOWNLOAD="${2:-}"

# ── Read version ──
VERSION=$(grep '^version:' pubspec.yaml | head -1 | sed 's/version:\s*//' | cut -d'+' -f1)
echo "==> Building Prepper Pad v${VERSION} for country: ${COUNTRY}"

# ── Read profile ──
PROFILE_FILE="scripts/country-profiles.yaml"
if [ ! -f "$PROFILE_FILE" ]; then
  echo "ERROR: $PROFILE_FILE not found"
  exit 1
fi

# Parse YAML with Python
PROFILE_JSON=$(python3 -c "
import json, sys
# Simple YAML parser for our flat structure
with open('$PROFILE_FILE') as f:
    text = f.read()
# Use PyYAML if available, else manual parse
try:
    import yaml
    data = yaml.safe_load(text)
    profiles = data.get('profiles', {})
    if '$COUNTRY' not in profiles:
        print(f'ERROR: Country profile not found: $COUNTRY', file=sys.stderr)
        print(f'Available: {list(profiles.keys())}', file=sys.stderr)
        sys.exit(1)
    print(json.dumps(profiles['$COUNTRY']))
except ImportError:
    print(json.dumps({'error': 'PyYAML not installed. Run: pip install pyyaml'}))
" 2>&1) || { echo "Failed to parse profile"; exit 1; }

if echo "$PROFILE_JSON" | grep -q '"error"'; then
  echo "$PROFILE_JSON"
  exit 1
fi

echo "==> Profile: $PROFILE_JSON"

# Extract fields
LANG=$(echo "$PROFILE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('language','es'))")
MAPS=$(echo "$PROFILE_JSON" | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin).get('maps',[])))")

echo "==> Language: $LANG"
echo "==> Maps: $MAPS"

# ── Prepare bundled maps ──
BUNDLED_MAPS="assets/bundled_library/maps"
mkdir -p "$BUNDLED_MAPS"

# Clean previous maps (keep the ones we're about to use)
for MAP_ID in $MAPS; do
  PMTILES_FILE="$BUNDLED_MAPS/${MAP_ID}.pmtiles"
  SOURCE_MAP="$HOME/PrepperPad/maps/${MAP_ID}.pmtiles"

  if [ -f "$PMTILES_FILE" ]; then
    echo "==> Map already bundled: ${MAP_ID}.pmtiles ($(du -h "$PMTILES_FILE" | cut -f1))"
    continue
  fi

  if [ -f "$SOURCE_MAP" ]; then
    echo "==> Copying map from PrepperPad: ${MAP_ID}.pmtiles ($(du -h "$SOURCE_MAP" | cut -f1))"
    cp "$SOURCE_MAP" "$PMTILES_FILE"
    continue
  fi

  if [ "$SKIP_DOWNLOAD" = "--no-map-download" ]; then
    echo "WARN: Map not found for $MAP_ID and --no-map-download set. Skipping."
    continue
  fi

  # Try to extract from Protomaps using pmtiles CLI
  if command -v pmtiles &>/dev/null; then
    echo "==> Extracting map ${MAP_ID} from Protomaps daily build..."
    BBOX=$(python3 -c "
import json
with open('assets/map_catalog.json') as f:
    cat = json.load(f)
for r in cat['regions']:
    if r['id'] == '$MAP_ID':
        print(r['bbox'])
        break
" 2>/dev/null)

    if [ -n "$BBOX" ]; then
      echo "    bbox=$BBOX"
      TMP_PMTILES="/tmp/${MAP_ID}.pmtiles"
      pmtiles extract \
        "https://protomaps.github.io/PMTiles/protomaps(vector)ODbL_delta.pmtiles" \
        "$TMP_PMTILES" \
        --bbox "$BBOX" \
        --maxzoom 14 \
        --overwrite 2>&1 || {
          echo "WARN: pmtiles extract failed for $MAP_ID. Map will be missing."
          continue
        }
      cp "$TMP_PMTILES" "$PMTILES_FILE"
      echo "    Done: $(du -h "$PMTILES_FILE" | cut -f1)"
    else
      echo "WARN: Map $MAP_ID not in catalog. Skipping."
    fi
  else
    echo "WARN: pmtiles CLI not installed and map not found for $MAP_ID."
    echo "      Install: npm install -g pmtiles"
    echo "      Or download manually to $SOURCE_MAP"
  fi
done

# ── Regenerate bundle manifest ──
echo "==> Regenerating bundled library manifest..."
python3 scripts/update_bundle_manifest.py

# ── Build APK ──
export PATH="$HOME/development/flutter/bin:$PATH"

# Set the default language for first launch
# (The app auto-detects device locale, but we can hint the preferred language)
export PREPPER_PAD_DEFAULT_LANG="$LANG"

echo "==> Building APK..."
flutter build apk --release 2>&1 | tail -5

# ── Copy to dist with country suffix ──
APK_SRC="build/app/outputs/flutter-apk/app-release.apk"
APK_DST="dist/prepper-pad-v${VERSION}-${COUNTRY}.apk"
mkdir -p dist
cp "$APK_SRC" "$APK_DST"

# SHA-256
SHA=$(shasum -a 256 "$APK_DST" | cut -d' ' -f1)
echo "$SHA  prepper-pad-v${VERSION}-${COUNTRY}.apk" > "dist/CHECKSUMS-v${VERSION}-${COUNTRY}.txt"

echo ""
echo "==> Done!"
echo "    APK: $APK_DST ($(du -h "$APK_DST" | cut -f1))"
echo "    SHA-256: $SHA"
echo "    Language: $LANG"
echo "    Maps: $MAPS"
