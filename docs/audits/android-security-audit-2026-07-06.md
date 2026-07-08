# Auditoría Android / Seguridad — Prepper Pad — 2026-07-06

## Resumen ejecutivo
Se auditó la superficie principal de riesgo de la app Android/Flutter: manifiesto Android, canales nativos Kotlin, updater/instalador LAN, servidor local de contenido, mesh/BLE/LAN, filesystem y patrones tipo secretos/XSS/path traversal.

Estado después de correcciones:
- `flutter analyze`: ✅ sin issues
- `flutter test`: ✅ 218 tests passed
- `flutter build apk --release`: ✅ APK generado
- APK dist verificado: ✅ `version.json`, `CHECKSUMS` y APK coinciden
- Escaneo de secretos hardcodeados: ✅ `secret_like_matches=0`
- Node syntax check: ✅ `node --check installer-server/server.js && node --check demo-server/server.js`

## Hallazgos corregidos

### P1 — Updater podía consumir RAM/disk de forma peligrosa con APK/DMG grandes
**Archivos:**
- `lib/modules/update/update_manifest.dart`
- `lib/modules/update/update_service.dart`
- `lib/modules/update/update_page.dart`
- `test/update_manifest_test.dart`
- `test/update_service_test.dart`

**Riesgo:**
El updater verificaba `sha256` con `readAsBytes()` sobre el archivo descargado. En builds autosuficientes de ~1.4GB esto podía disparar memoria en Android y matar la app. Además, `sizeBytes`/`sha256` eran opcionales, así que un manifiesto defectuoso o malicioso podía causar descargas no acotadas o sin verificación fuerte.

**Fix aplicado:**
- `sha256` y `sizeBytes` ahora son obligatorios y validados como 64 hex + tamaño positivo.
- Descarga aborta si recibe más bytes que `sizeBytes`.
- Descarga falla si recibe menos bytes que `sizeBytes`.
- Hash del instalador se calcula por stream (`sha256.bind(part.openRead())`) en vez de cargar todo a RAM.
- URL del instalador debe ser `http/https`, sin credenciales, y same-origin con el manifiesto LAN.
- Nombre del instalador se valida con allowlist segura.

**Tests agregados/actualizados:**
- rechaza manifiestos sin sha256/tamaño
- rechaza instaladores cross-origin
- mantiene soporte para URL relativa del installer-server
- mantiene rechazo de sha256 incorrecto

### P1 — `installer-server` podía exponer datos privados dentro de `~/PrepperPad`
**Archivo:** `installer-server/server.js`

**Riesgo:**
`/content/:type/:filename` aceptaba tipos arbitrarios mientras la ruta quedara dentro de `~/PrepperPad`. En una LAN, alguien podía intentar leer cosas que no son paquetes públicos: `.settings.json`, notas, `mesh/channels.json`, identidad/canales, etc.

**Fix aplicado:**
- `/content` queda restringido a tipos públicos:
  - `zim` → `.zim`
  - `maps` → `.pmtiles`
  - `models` → `.gguf`
- Se rechazan rutas anidadas, extensiones inesperadas y nombres inseguros.
- `Content-Disposition` ahora sanitiza el filename para evitar problemas de header injection.

**Test agregado:**
- `test/installer_server_security_test.dart` levanta el servidor Node real con un HOME temporal y prueba que:
  - `/content/maps/ok.pmtiles` sí responde 200
  - `/content/./.settings.json` no responde 200
  - `/content/notes/private.md` no responde 200
  - `/content/mesh/channels.json` no responde 200
  - traversal hacia `.settings.json` no responde 200

### P1 — Copia nativa de assets offline podía perder el archivo anterior si el reemplazo fallaba
**Archivo:** `android/app/src/main/kotlin/com/prepperpad/prepper_pad/MainActivity.kt`

**Riesgo:**
En `copyBundledAsset`, después de escribir y verificar el `.tmp`, el código borraba `dest` antes de renombrar. Si el rename fallaba, el usuario podía perder un mapa/ZIM/modelo offline ya instalado.

**Fix aplicado:**
- Se reemplazó el delete+rename por un flujo con backup y rollback best-effort:
  - si no existe destino: rename directo
  - si existe: renombrar destino a `.bak`, mover tmp, borrar backup
  - si falla el move: restaurar backup

### P2 — Release signing estaba atado a debug key
**Archivo:** `android/app/build.gradle.kts`

**Riesgo:**
El build `release` usaba siempre `signingConfigs.getByName("debug")`. Eso sirve para QA local, pero no para distribución real.

**Fix aplicado:**
Se agregó soporte de signing por variables de entorno:
- `PREPPER_PAD_KEYSTORE`
- `PREPPER_PAD_KEY_ALIAS`
- `PREPPER_PAD_STORE_PASSWORD`
- `PREPPER_PAD_KEY_PASSWORD` opcional; si falta usa store password

Si esas variables existen y el keystore existe, Gradle usa `releaseEnv`. Si no, mantiene fallback debug para que el QA local siga generando APK.

**Pendiente para deploy real:**
El APK generado en esta sesión se construyó sin esas variables, por lo que sigue siendo APK de QA/local firmado con debug fallback. Código listo ≠ deploy listo.

### P2 — Landing del instalador podía duplicar APKs grandes en memoria del navegador
**Archivos:**
- `installer-server/public/index.html`
- `test/installer_server_security_test.dart`

**Riesgo:**
La página LAN descargaba instaladores con `fetch()`, acumulaba todos los chunks en un arreglo y luego construía un `Blob`. Para APKs autosuficientes de ~1.4GB esto duplica memoria en Android Chrome/WebView y puede matar el navegador antes de que el usuario instale la app.

**Fix aplicado:**
- Para instaladores grandes (>100MB), tamaño desconocido o navegadores sin `ReadableStream`, la página usa descarga nativa del navegador (`<a download>`), que aprovecha `Content-Length`/`Range` del servidor y evita buffering JS.
- El modo con progreso queda limitado a archivos pequeños.
- Si el servidor revela en headers que el archivo es grande, se cancela el stream (`resp.body?.cancel()`) y se cambia a descarga nativa.
- Los botones incluyen `data-size` para decidir antes de iniciar la descarga.

**Test agregado:**
- `test/installer_server_security_test.dart` valida que el landing tenga umbral de descarga nativa, `data-size`, cancelación de stream y fallback a descarga nativa.

## Riesgos restantes / backlog recomendado

### P1 deploy — Firma real de release
Crear keystore de producción, guardarlo fuera del repo, configurar las variables anteriores y reconstruir. Sin esto no llamar “deploy listo”.

### P2 build future-proof — Gradle/AGP/Kotlin
El build actual pasa, pero Flutter avisó que pronto dejará de soportar:
- Gradle `8.9.0` → recomendado `>=8.14.0`
- Android Gradle Plugin `8.7.3` → recomendado `>=8.11.1`
- Kotlin `2.1.0` → recomendado `>=2.2.20`

No bloquea este build, pero conviene agendar upgrade controlado.

### P2 updater authenticity
El updater ahora exige integridad (`sha256`) y same-origin LAN, pero no hay firma criptográfica offline del manifiesto. Para un modelo adversarial fuerte en LAN hostil, agregar firma Ed25519 del `version.json` con public key embebida en la app.

### P2 mesh emergency plaintext
El canal `EMERGENCIA` es plaintext por diseño para que SOS llegue a desconocidos cercanos. Correcto para rescate, pero debe mantenerse claro en UI/documentación: nombre, nota y ubicación SOS pueden ser vistos por cualquier Prepper Pad cercano.

## Evidencia de verificación

```text
flutter analyze
→ No issues found!

flutter test
→ 218 tests passed!

node --check installer-server/server.js && node --check demo-server/server.js
→ exit_code 0

flutter test test/installer_server_security_test.dart
→ 2 tests passed

secret scan
→ secret_like_matches=0

flutter build apk --release
→ Built build/app/outputs/flutter-apk/app-release.apk (1463.6MB)

APK dist verification
sha256: a55ab579582f92204b15154db4b6c78df83672d95d7ba53ef14a97105da45869
sizeBytes: 1463632884
checks:
  apk_exists: true
  version_sha_match: true
  checksum_sha_match: true
  version_size_match: true
  url_match: true
```
