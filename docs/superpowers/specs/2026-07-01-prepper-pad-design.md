# Prepper Pad — Diseño v1 (MVP macOS)

**Fecha:** 2026-07-01
**Estado:** Aprobado por el usuario en sesión de brainstorming

## Resumen

Prepper Pad es una app nativa multiplataforma de conocimiento offline, inspirada en
Project N.O.M.A.D. (Apache 2.0) pero sin su arquitectura de servidor: en lugar de
orquestar contenedores Docker, Prepper Pad lee directamente los formatos de contenido
estándar dentro de una sola app con ícono. Sin Docker, sin navegador visible, sin
configuración de red. 100% funcional sin internet una vez descargado el contenido.

**Plataformas objetivo:** macOS (MVP, verificado), Windows, Linux x64/ARM64
(Raspberry Pi), Android — vía CI. iOS queda fuera (requiere cuenta Apple Developer;
decisión del usuario: sin teléfono por ahora).

**Distribución:** estilo "Hermes" — `.dmg` descargable desde GitHub Releases,
arrastrar a Aplicaciones. Sin App Store. (Sin firma Apple: primera apertura con
clic derecho → Abrir; firma de desarrollador es mejora futura.)

## Decisiones clave

| Decisión | Elección | Razón |
|---|---|---|
| Framework | Flutter (Dart) | Un código → macOS/Windows/Linux/Android nativos |
| Lectura ZIM | Parser Dart propio + FFI (liblzma del sistema, zstd dylib propia) | Sin dependencia de kiwix-serve ni puertos; control total |
| IA local | llama.cpp compilado con Metal, embebido como proceso interno | Lo mismo que hacen LM Studio/Ollama; AirLLM descartado (segundos por token, inviable para chat) |
| Mapas | flutter_map + PMTiles (Dart puro) | Formato Protomaps, sin motor nativo extra |
| Contenido | Carpeta única portable `~/PrepperPad/` | Se copia entre dispositivos por USB; nunca se re-descarga |

### Nota sobre AirLLM
El usuario pidió AirLLM; se evaluó y descartó con su acuerdo: AirLLM optimiza
*memoria* sacrificando velocidad (capa por capa desde disco → segundos por token),
inviable para chat interactivo. El objetivo real ("correr mejores modelos en poca
RAM") se logra con: mmap de llama.cpp, cuantización 4-bit, y modelos MoE
(p. ej. Qwen3-30B-A3B: activa ~3B por token) destacados en el catálogo.

## Estructura de la biblioteca portable

```
~/PrepperPad/
├── zim/      # Wikipedia, medicina, supervivencia (.zim)
├── maps/     # regiones offline (.pmtiles)
├── models/   # modelos IA (.gguf)
└── notes/    # notas markdown (.md)
```

Misma filosofía que el `storage/` de NOMAD, sin MySQL. La app detecta e importa
una carpeta `PrepperPad/` existente (p. ej. en un USB) en el wizard inicial.

## Módulos

1. **Biblioteca** — lista los ZIM, búsqueda por título, lectura de artículos con
   imágenes. Parser ZIM propio: header, MIME list, dirents, clusters comprimidos
   (zstd vía dylib compilada de la amalgamación `zstddeclib.c`; lzma vía liblzma
   del sistema). ZIM corrupto → se marca sin tumbar la biblioteca.
2. **Asistente IA** — chat streaming con modelos GGUF locales. llama-server
   (compilado con Metal) corre como proceso hijo en 127.0.0.1 con puerto efímero,
   detalle interno invisible al usuario. Chequeo de RAM libre antes de cargar un
   modelo (aviso, no bloqueo). Fase 2: RAG "preguntar a la biblioteca".
3. **Mapas** — visor offline de regiones PMTiles con estilo Protomaps.
4. **Notas** — editor/preview markdown sobre archivos locales con autosave.
5. **Depósito** (mejora del "Supply Depot" de NOMAD) — catálogo con internet:
   OPDS de Kiwix (library.kiwix.org), lista curada de GGUF, importación de
   .pmtiles. Descargas reanudables (HTTP Range) con verificación. Sin internet:
   muestra lo instalado, sin errores.

**Fuera del MVP:** Kolibri/cursos (requiere motor Python; fase posterior o app
oficial de Kolibri en paralelo), multiusuario, sincronización automática, RAG.

## Manejo de errores

- Sin internet: todo funciona; Depósito lo indica.
- Descarga interrumpida: reanudable desde el byte donde quedó.
- Modelo > RAM libre: aviso antes de cargar.
- ZIM corrupto: detectado y marcado.
- llama-server caído: reinicio automático con backoff; error visible en el chat.

## Pruebas

- Unit tests: parser ZIM (con fixture mini-ZIM de Wikipedia ~50MB del repo NOMAD),
  catálogo OPDS, cola de descargas, estructura de biblioteca.
- Verificación end-to-end en macOS: instalar el .dmg → leer artículo sin red →
  chatear con modelo → ver mapa → crear nota → descarga reanudable.
- CI compila las 5 plataformas; solo macOS queda *verificado* en esta fase.
  README documenta honestamente el estado por plataforma.

## Orden de construcción

1. Toolchain (Flutter sin Homebrew) + scaffold + wizard
2. Biblioteca ZIM (núcleo que valida todo)
3. Depósito (descargas)
4. IA (llama.cpp Metal)
5. Mapas
6. Notas + empaquetado .dmg + CI multi-plataforma

## Contexto de hardware del usuario

MacBook M3 Pro, 18GB RAM (justa), 139GB disco libre. Xcode 26 instalado; sin
Homebrew (toolchain se instala sin sudo: Flutter zip, CocoaPods user-gem,
cmake vía pip). Dispositivo futuro: Raspberry Pi 4/5 autosuficiente y tablet
Android — cubiertos por los builds Linux ARM64 y Android del CI.
