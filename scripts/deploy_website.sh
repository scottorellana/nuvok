#!/usr/bin/env bash
# Publica nuvok.org en producción de una sola pasada (idempotente: puedes
# correrlo cuantas veces quieras). Hace TODO lo automatizable:
#   1. Verifica/arma el paquete (site/ + downloads/).
#   2. Sube el sitio a Cloudflare Pages (crea el proyecto si no existe).
#   3. Crea el bucket R2 si no existe.
#   4. Sube los binarios a R2 con rclone (reanuda si se corta).
#
# Lo ÚNICO que tú tienes que hacer antes (una sola vez):
#   a) `npx wrangler login`         → autoriza Cloudflare en el navegador.
#   b) Crear un token de API de R2 y configurar el remote de rclone:
#         rclone config create r2 s3 provider Cloudflare \
#           access_key_id TU_KEY secret_access_key TU_SECRET \
#           endpoint https://TU_ACCOUNT_ID.r2.cloudflarestorage.com acl private
#   Detalles en website/DEPLOY.md (PARTE A/B/D).
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="nuvok"
BUCKET="nuvok-downloads"
SITE="dist/website-deploy/site"
DOWNLOADS="dist/website-deploy/downloads"
RCLONE="$(command -v rclone || echo "$HOME/bin/rclone")"

say()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ── 0. Paquete de producción ──────────────────────────────────────────────
if [[ ! -d "$SITE" || ! -d "$DOWNLOADS" ]]; then
  say "No existe el paquete; lo armo con package_website.sh"
  ./scripts/package_website.sh
fi
[[ -f "$SITE/index.html" ]]        || die "Falta $SITE/index.html — corre ./scripts/package_website.sh"
ls "$DOWNLOADS"/*.apk >/dev/null 2>&1 || die "Faltan binarios en $DOWNLOADS — corre ./scripts/package_website.sh"

# ── 1. Autenticación de Cloudflare ────────────────────────────────────────
say "Verificando sesión de Cloudflare (wrangler)"
if ! npx --yes wrangler whoami >/dev/null 2>&1 || npx --yes wrangler whoami 2>&1 | grep -qi 'not authenticated'; then
  die "No hay sesión de Cloudflare. Corre primero:  npx wrangler login"
fi
npx --yes wrangler whoami 2>&1 | grep -i 'account' | head -3 || true

# ── 2. Sitio → Cloudflare Pages ───────────────────────────────────────────
say "Subiendo el sitio a Cloudflare Pages (proyecto: $PROJECT)"
# create-project es idempotente: si ya existe, wrangler sigue sin romper.
npx --yes wrangler pages project create "$PROJECT" --production-branch main >/dev/null 2>&1 || true
npx --yes wrangler pages deploy "$SITE" --project-name "$PROJECT" --commit-dirty=true

# ── 3. Bucket R2 ──────────────────────────────────────────────────────────
say "Asegurando el bucket R2 ($BUCKET)"
npx --yes wrangler r2 bucket create "$BUCKET" >/dev/null 2>&1 \
  && echo "   bucket creado" \
  || echo "   bucket ya existía (ok)"

# ── 4. Binarios → R2 ──────────────────────────────────────────────────────
say "Subiendo binarios a R2 con rclone"
[[ -x "$RCLONE" ]] || die "rclone no encontrado. Instálalo (ver website/DEPLOY.md PARTE B)."
if ! "$RCLONE" listremotes 2>/dev/null | grep -q '^r2:'; then
  die "rclone no tiene el remote 'r2'. Configúralo con tus llaves de R2 (ver website/DEPLOY.md PARTE D3)."
fi
"$RCLONE" copy "$DOWNLOADS/" "r2:$BUCKET/" --progress

# ── 5. Recordatorio de dominios (una sola vez, en el panel) ────────────────
say "LISTO — subida completa."
cat <<'EON'

Si es la PRIMERA publicación, conecta los dominios en el panel de Cloudflare
(una sola vez; después ya no hace falta):

  • Sitio:      Workers & Pages → nuvok → Custom domains → añade  nuvok.org
  • Descargas:  R2 → nuvok-downloads → Settings → Public access →
                Custom Domains → conecta  downloads.nuvok.org

Verifica al final:
  curl -s https://nuvok.org/version.json | head
  curl -s -I -r 0-1023 https://downloads.nuvok.org/nuvok-android-v0.5.0.apk | head -1
EON
