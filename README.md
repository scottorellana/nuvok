# Nuvok

**Conocimiento que no se apaga.** Una sola app nativa con tu biblioteca de
supervivencia offline: Wikipedia completa, mapas, asistente de IA local y
notas — todo funcionando **sin internet**, sin servidores y sin configuración.

Inspirada en [Project N.O.M.A.D.](https://github.com/Crosstalk-Solutions/project-nomad)
(Apache 2.0), pero repensada como app de escritorio/móvil en lugar de un
servidor Docker: se instala con doble clic en cualquier dispositivo.

## Módulos

| Módulo | Qué hace | Formato |
|---|---|---|
| 🚨 Emergencia | Guías propias de primeros auxilios (RCP, hemorragias, atragantamiento…) con búsqueda por síntoma, ES/EN | embebido |
| 📖 Biblioteca | Wikipedia, guías médicas y libros offline | `.zim` (Kiwix) |
| 🧠 Asistente IA | Chat con modelos locales (llama.cpp + Metal/GPU) + modo Emergencia | `.gguf` |
| 🗺️ Mapas | Mapas offline con GPS, ruteo por calles (respeta accesos), POIs y "llévame a…" | `.pmtiles` (Protomaps) |
| 📡 Comunicación | Mesh sin internet (WiFi): chat cifrado por canal, SOS y posiciones del grupo; LoRa a futuro | — |
| 📝 Notas | Notas markdown locales | `.md` |
| 📦 Depósito | Catálogo para descargar contenido, mapas y **actualizaciones de la app** (solo aquí se usa internet) | — |

## La biblioteca portable

Todo el contenido vive en una carpeta `Nuvok/` en tu usuario:

```
Nuvok/
├── zim/      ← biblioteca (.zim)
├── maps/     ← mapas (.pmtiles)
├── models/   ← modelos IA (.gguf)
├── mesh/     ← identidad, canales e historial de Comunicación
└── notes/    ← tus notas (.md)
```

Cópiala por USB a otro dispositivo con Nuvok y todo tu contenido viaja
con ella — nunca se descarga dos veces.

## Estado por plataforma

| Plataforma | Estado |
|---|---|
| macOS (Apple Silicon) | ✅ Verificado — `.dmg` en Releases |
| Linux x64 / ARM64 (Raspberry Pi) | 🏗️ Compila en CI — pendiente de prueba en hardware real |
| Windows 10/11 | 🏗️ Compila en CI — pendiente de prueba en hardware real |
| Android | 🏗️ Compila en CI — pendiente de prueba en hardware real |
| iOS | ❌ Fuera de alcance por ahora (requiere cuenta Apple Developer) |

## Instalación (macOS)

1. Descarga el `.dmg` de la última release.
2. Arrastra **Nuvok** a Aplicaciones.
3. Primera vez: clic derecho → Abrir (la app no está firmada por Apple aún).

## Instalador web local

`node installer-server/server.js` levanta una página privada (solo tu red
WiFi, puerto 8848) para descargar e instalar la app en cualquier dispositivo
directo desde el navegador — detecta el sistema operativo del visitante, y
también sirve el contenido ya descargado (libros, mapas, modelos IA) para
compartirlo entre dispositivos sin repetir la descarga.

## Actualizaciones

La app revisa opcionalmente (`lib/modules/update/`) si hay una versión nueva
cuando detecta internet, y ofrece descargarla e instalarla — nunca se
actualiza sola ni bloquea el uso offline si no hay conexión. El mismo
`installer-server` expone `/version.json` con la versión, tamaño y sha256 de
los binarios en `dist/`, calculados en el momento — sirve para probar el
sistema completo en tu red. El manifiesto público es independiente del repo
de código (privado): un repo privado no puede servir binarios a cualquier
dispositivo sin exponer un token, así que el canal de actualización necesita
un host público propio (repo de solo-releases, GitHub Pages, o tu dominio).

## Desarrollo

Requisitos: Flutter ≥ 3.44, Xcode (macOS). Los motores nativos se compilan
con `scripts/build_native_macos.sh` (zstd + llama-server) antes del primer
`flutter run -d macos`.

```bash
./scripts/build_native_macos.sh   # compila zstd y llama-server (una vez)
flutter pub get
flutter test                      # incluye tests del parser ZIM con fixture real
flutter run -d macos
```

Empaquetado: `./scripts/package_macos.sh` produce `dist/Nuvok.dmg`.

## Licencia

Copyright © 2026 Scott Orellana.

Nuvok es software libre bajo la **[GNU General Public License v3](LICENSE)**.
Puedes usarlo, estudiar su código, modificarlo y redistribuirlo bajo esos
mismos términos. Se entrega **sin ninguna garantía**.

Que el código sea abierto es deliberado: una app que promete que nada sale de
tu dispositivo debe poder demostrarlo. Cualquiera puede auditar el cifrado de
la malla y verificar que la IA corre local. La GPL además asegura que las
mejoras de la comunidad vuelvan a la comunidad.

**Vender binarios es compatible con la GPL.** Nuvok se compra en nuvok.org;
la licencia obliga a entregar el código fuente a quien reciba el binario, no
a regalar el binario.

Una consecuencia a tener presente: la GPL v3 es **incompatible con la App
Store de Apple** (sus términos imponen restricciones de uso que la GPL
prohíbe). Nuvok se distribuye directo desde el sitio, así que no aplica hoy.
Si algún día quisieras entrar a la App Store, como único titular del
copyright podrías publicar ahí bajo una licencia propia sin dejar de mantener
este repositorio en GPL.

Nuvok incorpora trabajo de terceros con sus propias licencias —
[llama.cpp](https://github.com/ggml-org/llama.cpp) (MIT),
[zstd](https://github.com/facebook/zstd) (BSD), modelos Apache 2.0, el
catálogo de [Kiwix](https://kiwix.org) (CC BY-SA) y mapas de
[Protomaps](https://protomaps.com)/OpenStreetMap (ODbL). Los avisos que esas
licencias exigen están en [NOTICE.md](NOTICE.md) y dentro de la app, en
Ajustes → Créditos y licencias.

El contenido empaquetado (mapas, enciclopedia, modelos) **no es de Nuvok** y
conserva su licencia original: la GPL cubre el código, no ese material.

### Marca

«Nuvok», su logo y nuvok.org **no** forman parte de la licencia: identifican
las compilaciones oficiales. Un fork puede usar todo el código bajo la GPL,
pero debe distribuirse con otro nombre y otro logo. Es la misma regla de
Firefox o Grafana: el código es libre; la confianza en el nombre, no.
