# Publicar nuvok.org — era del muro de descarga

Arquitectura (spec `docs/superpowers/specs/2026-07-29-muro-de-descarga-design.md`):

| Pieza | Qué es | Dónde va |
|---|---|---|
| **Sitio** | `dist/website-deploy/site/` (estático, ~1 MB) | Cloudflare **Pages** |
| **Binarios** | `dist/website-deploy/r2-upload/` (APK+DMG+`releases.json`) | R2 `nuvok-releases` (privado) |
| **Tienda** | `store-worker/` (webhook Lemon Squeezy + entrega con clave) | Cloudflare **Worker** |
| **Compras** | D1 `nuvok-purchases` | **ya creada** (2026-07-30, esquema aplicado) |

Los binarios NO son públicos: solo el Worker los entrega, contra clave de
compra. Costo mensual: $0 (R2 no cobra tráfico de salida).

## Pasos del dueño (una sola vez)

1. **Activar R2**: panel de Cloudflare → R2 → *Enable R2* (acepta términos).
2. **DNS**: panel → *Add a site* → `nuvok.org` (plan Free) → copiar los dos
   nameservers → pegarlos en tu registrador. Activo cuando llegue el correo
   "nuvok.org is active".
3. **Autorizar wrangler** (un clic en el navegador):
   ```bash
   npx wrangler login
   ```
4. **Lemon Squeezy**: crear la tienda y el producto ($99, entrega digital
   desactivada — la entrega la hace nuestro Worker). Copiar:
   - la **URL del checkout** → pegarla en `website/app.js` → `NUVOK_CONFIG.checkoutUrl`
   - crear el **webhook** → URL `https://nuvok.org/webhook/lemonsqueezy`,
     evento `order_created` y `order_refunded` → copiar el *signing secret*
     (se guarda en el paso de deploy, nunca en el repo).
5. **GHL / Hexona (opcional, CRM)**: del panel copiar el embed del formulario
   y el script del chat → `NUVOK_CONFIG.ghlFormUrl` / `ghlChatWidgetSrc`.
   Para que cada comprador caiga al CRM: crear una *Private Integration* y
   tener a mano token + Location ID (van como secrets del Worker).

## Deploy (cada release)

```bash
# 1. Binarios frescos (ligeros: la app baja su contenido en el primer arranque)
./scripts/build_android_release_signed.sh
./scripts/package_macos.sh
./scripts/package_website.sh          # → dist/website-deploy/ + manifiestos

# 2. Bucket (solo la primera vez)
npx wrangler r2 bucket create nuvok-releases

# 3. Subir binarios + manifiesto del Worker (el script imprime los comandos
#    exactos con la versión del día)
npx wrangler r2 object put "nuvok-releases/<binario>" --file="dist/website-deploy/r2-upload/<binario>"
npx wrangler r2 object put nuvok-releases/releases.json --file=dist/website-deploy/r2-upload/releases.json

# 4. Sitio
npx wrangler pages deploy dist/website-deploy/site --project-name=nuvok

# 5. Worker de la tienda (desde store-worker/; primera vez pide los secrets)
cd store-worker
npx wrangler secret put LS_SIGNING_SECRET     # pegar el del webhook LS
npx wrangler secret put GHL_TOKEN             # opcional (CRM)
npx wrangler secret put GHL_LOCATION_ID       # opcional (CRM)
npx wrangler deploy
```

## Verificación de lanzamiento

1. Compra de PRUEBA en Lemon Squeezy (modo test) → llega el correo con la
   clave → `nuvok.org/descargas.html` la acepta y lista los binarios.
2. Descargar el DMG con la clave y verificar su SHA-256 contra el publicado.
3. Clave inventada → "Clave no válida". Reembolsar la compra test → la clave
   queda revocada.
4. `https://nuvok.org/version.json` responde la versión (el chequeo de
   actualización de la app lo usa).

## Dominio pendiente en el registrador

`hola@nuvok.org` debe existir (redirección de correo del registrador o
Cloudflare Email Routing) — el sitio y la app lo citan como soporte.
