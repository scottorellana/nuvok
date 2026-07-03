# Prepper Pad

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
| 📦 Depósito | Catálogo para descargar contenido y mapas (solo aquí se usa internet) | — |

## La biblioteca portable

Todo el contenido vive en una carpeta `PrepperPad/` en tu usuario:

```
PrepperPad/
├── zim/      ← biblioteca (.zim)
├── maps/     ← mapas (.pmtiles)
├── models/   ← modelos IA (.gguf)
├── mesh/     ← identidad, canales e historial de Comunicación
└── notes/    ← tus notas (.md)
```

Cópiala por USB a otro dispositivo con Prepper Pad y todo tu contenido viaja
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
2. Arrastra **Prepper Pad** a Aplicaciones.
3. Primera vez: clic derecho → Abrir (la app no está firmada por Apple aún).

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

Empaquetado: `./scripts/package_macos.sh` produce `dist/PrepperPad.dmg`.

## Licencia

Apache 2.0. Usa [llama.cpp](https://github.com/ggml-org/llama.cpp) (MIT),
[zstd](https://github.com/facebook/zstd) (BSD), el catálogo público de
[Kiwix](https://kiwix.org) y mapas de [Protomaps](https://protomaps.com)
(ODbL/OpenStreetMap).
