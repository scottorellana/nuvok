#!/usr/bin/env bash
# Levanta un servidor de descarga en la red local para instalar el APK de
# Nuvok en un Android por WiFi (sin cable, sin tienda). Sirve SOLO el APK
# (no expone el repo). Abre en el Android:  http://<IP-del-Mac>:<PUERTO>/
set -euo pipefail
cd "$(dirname "$0")/.."

APK="dist/prepper-pad-full-v0.5.0.apk"
PORT="${1:-8770}"
SERVE_DIR="dist/lan-apk"

[[ -f "$APK" ]] || { echo "Falta $APK — corre ./scripts/build_android_release_signed.sh primero"; exit 1; }

rm -rf "$SERVE_DIR"
mkdir -p "$SERVE_DIR"
# Hardlink para no duplicar 1.7 GB.
ln "$APK" "$SERVE_DIR/nuvok-v0.5.0.apk"

SHA=$(shasum -a 256 "$APK" | awk '{print $1}')
cat > "$SERVE_DIR/index.html" <<HTML
<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>Descargar Nuvok</title>
<body style="font-family:system-ui;background:#0b0b0a;color:#eee;text-align:center;padding:2rem">
<h1>Nuvok para Android</h1>
<p>v0.5.0 · APK firmado · 1.6 GB</p>
<p><a href="nuvok-v0.5.0.apk" style="display:inline-block;background:#b7c56b;color:#111;
   padding:1rem 2rem;border-radius:12px;font-weight:700;text-decoration:none">Descargar APK</a></p>
<p style="font-size:.7rem;word-break:break-all;opacity:.6">SHA-256 $SHA</p>
</body>
HTML

IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "TU-IP-LAN")
echo ""
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  En el Android (misma red WiFi) abre el navegador │"
echo "  │  y entra a:                                       │"
echo "  │                                                   │"
printf  "  │     http://%s:%s/%*s│\n" "$IP" "$PORT" $((33 - ${#IP} - ${#PORT})) ""
echo "  │                                                   │"
echo "  │  Toca «Descargar APK» → abre el archivo → Instalar │"
echo "  └─────────────────────────────────────────────────┘"
echo ""
echo "Ctrl+C para detener el servidor."
cd "$SERVE_DIR"
exec python3 -m http.server "$PORT" --bind 0.0.0.0
