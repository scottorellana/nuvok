# Publicar nuvok.org — pasos exactos

Nuvok se sirve en **dos piezas** porque los instaladores pesan 1.6 GB cada uno
(no caben en un hosting web normal):

| Pieza | Qué es | Dónde va | Costo |
|-------|--------|----------|-------|
| **Sitio** | `dist/website-deploy/site/` (64 KB: html, css, js, version.json) | Cloudflare **Pages** | gratis |
| **Descargas** | `dist/website-deploy/downloads/` (APK + DMG, 3.2 GB) | Cloudflare **R2** | gratis (10 GB y sin cobro de tráfico) |

Total mensual: **$0** (solo pagaste el dominio). Todo lo hace un solo comando de
armado + unos pasos en el panel de Cloudflare.

> Antes de empezar, corre esto una vez para generar las carpetas:
> ```bash
> cd ~/prepper-pad && ./scripts/package_website.sh
> ```

---

## PARTE A — Preparar la cuenta y el dominio (una sola vez, ~15 min)

### A1. Crea una cuenta gratis en Cloudflare
Entra a <https://dash.cloudflare.com/sign-up>, regístrate con tu correo.

### A2. Agrega tu dominio
En el panel: **Add a site** → escribe `nuvok.org` → elige el plan **Free**.

### A3. Apunta el dominio a Cloudflare
Cloudflare te mostrará **dos nameservers** (algo como `xxx.ns.cloudflare.com`).
- Entra al sitio donde **compraste nuvok.org** (tu registrador).
- Busca "Nameservers" / "DNS" / "Servidores de nombres".
- **Reemplaza** los que tenga por los dos de Cloudflare.
- Guarda. Cloudflare tarda de minutos a unas horas en activarse (te llega un
  correo "nuvok.org is active").

---

## PARTE B — Herramientas (ya listas)

- **wrangler**: se usa vía `npx wrangler …` — no hace falta instalar nada.
- **rclone**: **ya quedó instalado** en `~/bin/rclone` (está en tu PATH, o sea
  que puedes escribir `rclone` directo).

No tienes que instalar nada en esta parte. Sigue a la C.

---

## PARTE C — Autenticarte + dar tus llaves de R2 (una sola vez, ~5 min)

Estos son los **dos únicos pasos manuales** que quedan; después el deploy es
un solo comando (PARTE D).

### C1. Autoriza Cloudflare
```bash
npx wrangler login          # abre el navegador → dale "Allow"
```

### C2. Consigue las llaves de R2 y configura rclone
Panel Cloudflare → **R2** → **Manage R2 API Tokens** → **Create API token** →
permiso **Object Read & Write** → **Create**. Copia el **Access Key ID**, el
**Secret Access Key** y tu **Account ID** (arriba a la derecha en R2). Luego:

```bash
rclone config create r2 s3 \
  provider Cloudflare \
  access_key_id TU_ACCESS_KEY_ID \
  secret_access_key TU_SECRET_ACCESS_KEY \
  endpoint https://TU_ACCOUNT_ID.r2.cloudflarestorage.com \
  acl private
```

---

## PARTE D — Publicar TODO con un comando

```bash
cd ~/prepper-pad
./scripts/deploy_website.sh
```

Ese script hace, en orden y sin que toques nada más:
1. Arma el paquete si falta.
2. Sube el sitio a **Pages** (crea el proyecto `nuvok` si no existe).
3. Crea el bucket **R2** `nuvok-downloads` si no existe.
4. Sube los binarios a R2 con rclone (reanuda si se corta).

Es **idempotente**: si algo falla a mitad, corrígelo y vuelve a correrlo.

### D1. Conecta los dominios (solo la PRIMERA vez, en el panel)
El script te lo recuerda al final. En el panel de Cloudflare:
- **Sitio**: Workers & Pages → **nuvok** → **Custom domains** → añade
  `nuvok.org` (y `www.nuvok.org` si quieres).
- **Descargas**: R2 → **nuvok-downloads** → **Settings** → **Public access →
  Custom Domains** → conecta `downloads.nuvok.org`. Cloudflare crea el DNS solo.

---

## PARTE E — Verificar que todo quedó (~2 min)

```bash
# El manifiesto que consulta la app:
curl -s https://nuvok.org/version.json | head

# Que la descarga responda (206 = perfecto, soporta reanudar):
curl -s -I -r 0-1023 https://downloads.nuvok.org/nuvok-android-v0.5.0.apk | head -1
```

Luego, en la vida real:
1. Abre **https://nuvok.org** en el teléfono → toca **Descargar APK** → debe
   empezar a bajar desde `downloads.nuvok.org`.
2. En un teléfono que YA tenga Nuvok: **Depósito → Buscar actualización** → debe
   decir "estás al día" (o instalar si subes una versión más nueva).

**¡Listo! nuvok.org está en producción.**

---

## Publicar una versión nueva (el día de mañana)

```bash
cd ~/prepper-pad
./scripts/build_android_release_signed.sh    # nuevo APK
cp build/app/outputs/flutter-apk/app-release.apk dist/prepper-pad-full-v0.5.0.apk
./scripts/package_macos.sh                   # nuevo DMG
# edita website/version.json (sube "version" y "notes") y los nombres en
# website/index.html si cambió el número
./scripts/deploy_website.sh                  # re-arma y publica sitio + R2
```
El `deploy_website.sh` re-arma el paquete (SHA-256 nuevos) y sube todo. Cada
Nuvok con internet verá la actualización en Depósito.

---

## Alternativa: un solo VPS (si prefieres tenerlo todo tuyo)

Si tienes un servidor con nginx, puedes servir sitio + descargas juntos:

1. En `scripts/package_website.sh` cambia `DL_BASE` a `""` (URLs relativas
   `/downloads/...`) y vuelve a correrlo.
2. `rsync -avz dist/website-deploy/site/ TU_VPS:/var/www/nuvok.org/`
   y `rsync -avz --progress dist/website-deploy/downloads/ TU_VPS:/var/www/nuvok.org/downloads/`
3. nginx: apunta `nuvok.org` a `/var/www/nuvok.org` y en `location /downloads/`
   agrega `add_header Accept-Ranges bytes;` (descargas reanudables).
4. TLS: `sudo certbot --nginx -d nuvok.org -d www.nuvok.org`.
5. En Cloudflare (o tu DNS) apunta `nuvok.org` a la IP del VPS.
