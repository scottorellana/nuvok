# Muro de descarga de Nuvok — diseño

**Fecha:** 2026-07-29 · **Estado:** aprobado en dirección (decisiones del
2026-07-29: muro de descarga estilo Ardour, GPL v3, CLA). Reemplaza al diseño
anterior de códigos de activación por 3 dispositivos.

## Resumen

Nuvok es GPL: cualquiera puede compilarlo gratis, y eso no cambia. Lo que se
vende en nuvok.org por **$99 (pago único)** es la conveniencia oficial:

| Incluye | Detalle |
|---|---|
| Binarios oficiales firmados | macOS `.dmg` y Android `.apk` hoy; Windows/Linux cuando estén verificados en hardware real |
| Actualizaciones | Todas las versiones 1.x incluidas. (Revisable: una futura 2.0 podrá ser upgrade con descuento — se decide entonces, no ahora.) |
| Canal de descarga confiable | URLs firmadas + SHA-256 publicados, reanudables |
| Fase 2: espejo de paquetes | Modelos/mapas/Wikipedia desde CDN propio (perk de velocidad; las fuentes gratuitas siguen funcionando) |

**Qué NO hay, por decisión:**
- **Sin activación en runtime.** Nada en la app se bloquea. Un fork GPL
  quitaría el candado en minutos; cobrar la descarga es honesto y funciona
  (Ardour lo prueba desde hace años).
- **Sin límite técnico de dispositivos.** La licencia de compra es "personal
  y de tu hogar" por términos, no por candado.
- **Sin cuentas ni contraseñas.** La clave de compra ES el acceso: menos
  fricción y menos superficie de ataque.
- **iPhone:** honestidad total — hoy se compila desde el código (gratis);
  cuando exista distribución App Store (doble licencia), los compradores la
  reciben sin pagar de nuevo.

## Arquitectura

```
Comprador ──► Lemon Squeezy (checkout $99, MoR)
                   │ webhook order_created (HMAC verificado)
                   ▼
            Cloudflare Worker ──► D1: {order_id, email, key, status, dl_count}
                   │ (LS envía el email con la clave y el enlace)
                   ▼
nuvok.org/descargas + clave ──► Worker valida ──► URLs firmadas R2 (1 h) + SHAs
```

**Stack: Cloudflare Workers + D1 + R2 + Pages.** Razones: `website/DEPLOY.md`
ya apuntaba a Pages+R2; la cuenta Cloudflare existe (MCP conectado a esta
máquina, se puede desplegar desde aquí); R2 no cobra egress (binarios de
cientos de MB); y es el mismo stack del portal CEMA — un solo paradigma que
mantener.

**Lemon Squeezy como Merchant of Record.** Vendiendo desde Honduras al mundo,
LS factura, cobra impuestos (IVA/sales tax) y gestiona reembolsos. Nosotros
nunca vemos tarjetas. La alternativa (Stripe directo) obliga a gestionar
impuestos internacionales: no para una persona sola.

### Flujo de compra

1. `nuvok.org` → botón Comprar → checkout alojado de Lemon Squeezy.
2. Webhook `order_created` al Worker. Se **verifica la firma HMAC** y se
   descarta cualquier payload sin ella. Idempotente por `order_id` (LS
   reintenta webhooks).
3. Worker genera `key` (UUIDv4) y guarda en D1:
   `{order_id, email, key, status: 'active', created_at, dl_count: 0}`.
4. El comprador recibe el email de LS con la clave y el enlace a
   `nuvok.org/descargas`.
5. En `/descargas` pega la clave → Worker valida (comparación de tiempo
   constante, respuestas uniformes para no permitir enumeración) → devuelve
   URLs firmadas de R2 con expiración de 1 hora + los SHA-256.
6. Webhook `order_refunded` → `status: 'revoked'`.

### Abuso, sin castigar al honesto

- Límite suave: **25 descargas/mes por clave** (un hogar real usa ~5; una
  clave publicada en un foro muere sola). Al exceder: mensaje claro con
  contacto, no bloqueo silencioso.
- Las URLs firmadas expiran en 1 h: compartir el enlace directo no sirve.
- No hay DRM que "vencer": el disuasivo es que compilar gratis ya es legal.

### Canal de actualizaciones en la app (Fase 2)

- `version.json` sigue **público** (saber que hay versión nueva no es secreto).
- El binario de la actualización pide la clave: en Depósito → App se puede
  pegar una vez (ajuste `downloadKey`); `update_service` la envía como header.
  **No es activación**: sin clave, la app funciona al 100% — solo la descarga
  del binario oficial la pide. 402/403 → mensaje honesto con enlace a compra.

### Datos y privacidad

D1 guarda solo `email + clave + contadores`. Las tarjetas viven en Lemon
Squeezy. Borrado a pedido = un DELETE. Nada de analytics en el Worker.

## Cumplimiento GPL

- Quien recibe el binario tiene derecho al código: el repositorio es público,
  y la página de descargas enlaza el commit/tag exacto de cada release.
- El muro cobra el ACCESO al binario oficial, no restringe los derechos GPL
  de quien ya lo tiene: un comprador puede redistribuir su copia (la licencia
  se lo da). El negocio no depende de impedirlo sino de que comprar sea más
  cómodo que buscar — exactamente el modelo Ardour.

## Implementación por fases

**Fase 1 — vender (bloqueada solo por cuentas del usuario):**
1. Crear producto en Lemon Squeezy (cuenta + aprobación de la tienda: usuario).
2. DNS de nuvok.org → Cloudflare (usuario).
3. Worker `nuvok-store`: webhook + validación + firma de URLs. Tests de
   firma inválida, refund, idempotencia.
4. D1 `nuvok_purchases` (una tabla). R2 `nuvok-releases` con los binarios
   y SHAs. Página `/descargas` en el sitio.
5. El sitio deja de ofrecer descargas abiertas (hoy `website/` las tiene
   públicas): quedan la clave y el botón de compra.

**Fase 2 — updates con clave:** ajuste `downloadKey` + header en
`update_service` + UI en Depósito → App.

**Fase 3 — espejo de paquetes en R2** (perk; las fuentes libres siguen).

## Verificación

- Worker: suite de tests del webhook (firma, idempotencia, refund, límite).
- End-to-end de staging: compra de prueba LS (modo test) → email → clave →
  descarga real con SHA correcto.
- App: test de que `update_service` añade la clave solo al binario (no al
  manifiesto) y muestra el mensaje honesto en 402/403.
