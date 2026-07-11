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

## PARTE B — Instalar las 2 herramientas (una sola vez, ~5 min)

Ya tienes `node`. Faltan `wrangler` (para el sitio) y `rclone` (para subir los
archivos grandes a R2). Copia y pega en la Terminal:

```bash
# wrangler (CLI oficial de Cloudflare)
npm install -g wrangler

# rclone (sube archivos de GB a R2 sin fallar; sin necesidad de Homebrew)
cd /tmp && curl -O https://downloads.rclone.org/rclone-current-osx-arm64.zip \
  && unzip -o rclone-current-osx-arm64.zip \
  && sudo cp rclone-*-osx-arm64/rclone /usr/local/bin/ \
  && sudo chmod +x /usr/local/bin/rclone \
  && rclone version
```

(El `sudo` te pedirá la contraseña de tu Mac.)

---

## PARTE C — Subir el SITIO a Pages (~3 min)

```bash
cd ~/prepper-pad
npx wrangler login          # abre el navegador, dale "Allow"
npx wrangler pages deploy dist/website-deploy/site --project-name nuvok
```

Cuando termine, conéctale tu dominio:
- Panel Cloudflare → **Workers & Pages** → proyecto **nuvok** → pestaña
  **Custom domains** → **Set up a custom domain** → escribe `nuvok.org` →
  confirma. (Repite para `www.nuvok.org` si quieres.)

Ya con esto `https://nuvok.org` muestra la página.

---

## PARTE D — Subir las DESCARGAS a R2 (~10 min según tu internet)

### D1. Crea el bucket
```bash
npx wrangler r2 bucket create nuvok-downloads
```

### D2. Consigue las llaves de R2
Panel Cloudflare → **R2** → **Manage R2 API Tokens** → **Create API token** →
permiso **Object Read & Write** → **Create**. Copia:
- **Access Key ID**
- **Secret Access Key**
- Tu **Account ID** (aparece en la página principal de R2, arriba a la derecha).

### D3. Configura rclone (pega tus 3 valores)
```bash
rclone config create r2 s3 \
  provider Cloudflare \
  access_key_id TU_ACCESS_KEY_ID \
  secret_access_key TU_SECRET_ACCESS_KEY \
  endpoint https://TU_ACCOUNT_ID.r2.cloudflarestorage.com \
  acl private
```

### D4. Sube los binarios (esto tarda; rclone reanuda si se corta)
```bash
cd ~/prepper-pad
rclone copy dist/website-deploy/downloads/ r2:nuvok-downloads/ --progress
```

### D5. Conecta el subdominio de descargas
Panel Cloudflare → **R2** → bucket **nuvok-downloads** → **Settings** →
**Public access → Custom Domains** → **Connect Domain** → escribe
`downloads.nuvok.org` → confirma. Cloudflare crea el DNS solo.

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
./scripts/package_macos.sh                   # nuevo DMG
# edita website/version.json (sube "version" y "notes") y los nombres en
# website/index.html si cambió el número
./scripts/package_website.sh                 # re-arma site/ + downloads/

npx wrangler pages deploy dist/website-deploy/site --project-name nuvok
rclone copy dist/website-deploy/downloads/ r2:nuvok-downloads/ --progress
```
Cada Nuvok con internet verá la actualización en Depósito.

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
