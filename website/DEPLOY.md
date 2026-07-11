# Desplegar nuvok.org

El sitio es 100 % estático. Lo único especial son los **binarios grandes**
(APK 1.6 GB + DMG 1.6 GB): superan los límites de los hostings estáticos
gratuitos (Cloudflare Pages/Netlify limitan archivos a 25 MB), así que van
en un almacenamiento de objetos o en un VPS.

## Armar el paquete

```bash
./scripts/package_website.sh
# → dist/website-deploy/  (index.html, css, js, version.json, downloads/*)
```

## Opción A (recomendada): Cloudflare Pages + R2

Costo ≈ $0 (R2 no cobra tráfico de salida; 10 GB de almacenamiento gratis).

1. **DNS**: transfiere los nameservers de nuvok.org a Cloudflare (plan Free).
2. **Sitio** — Cloudflare Pages:
   - Crea un proyecto "nuvok" → "Direct upload" → sube `dist/website-deploy/`
     SIN la carpeta `downloads/`.
   - Custom domain: `nuvok.org` (y `www.nuvok.org`).
3. **Binarios** — R2:
   - Crea un bucket `nuvok-downloads` y sube los 2 archivos de
     `dist/website-deploy/downloads/` (usa `rclone` o la web).
   - Conecta el bucket al dominio: R2 → Settings → Custom Domains →
     `downloads.nuvok.org`.
4. **Ruteo**: en el sitio, las descargas apuntan a `/downloads/...`. Crea una
   regla (Bulk Redirect o Worker de 5 líneas) que redirija
   `nuvok.org/downloads/*` → `downloads.nuvok.org/*`. Alternativa sin regla:
   cambiar los href del index.html y las `url` de version.json a
   `https://downloads.nuvok.org/...` (la app acepta URLs absolutas).

## Opción B: tu VPS (nginx)

Si prefieres tenerlo todo en tu VPS:

```bash
rsync -avz --progress dist/website-deploy/ usuario@TU_VPS:/var/www/nuvok.org/
```

```nginx
server {
  server_name nuvok.org www.nuvok.org;
  root /var/www/nuvok.org;
  location /downloads/ {
    add_header Accept-Ranges bytes;   # descargas reanudables
  }
}
```

TLS: `certbot --nginx -d nuvok.org -d www.nuvok.org`.

## Qué obtiene la app con esto

Cada Nuvok instalada consulta `https://nuvok.org/version.json` cuando tiene
internet (Depósito → Actualizaciones) y ofrece instalar la versión nueva
verificando SHA-256 y tamaño. Un servidor LAN configurado sigue teniendo
prioridad — el flujo offline no cambia.

## Checklist al publicar una versión nueva

1. `./scripts/build_android_release_signed.sh` y `./scripts/package_macos.sh`.
2. Actualizar `website/version.json` (versión + notas) y los nombres/links en
   `website/index.html`.
3. `./scripts/package_website.sh` y subir (Pages: sitio; R2/VPS: binarios).
4. Probar en un teléfono con la versión anterior: Depósito → Buscar
   actualización → debe ofrecer la nueva.
