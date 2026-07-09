# Roadmap aprobado: 10 mejoras para salvar vidas + guías de supervivencia

**Fecha:** 2026-07-09
**Estado:** Aprobado por el usuario. Prioridad #1: clips de voz (walkie-talkie
sin internet). Adición aprobada: ampliar las guías con temas de supervivencia
(balsa improvisada, refugio en la naturaleza, y otros).
**Base:** docs/superpowers/specs/2026-07-09-top10-ideas-salvar-vidas.md

## Orden de implementación

| Fase | Mejora | Por qué este orden |
|------|--------|--------------------|
| 1 | **Clips de voz por mesh (walkie-talkie)** | Prioridad explícita del usuario |
| 2 | **Guías de supervivencia nuevas** | Pedido explícito; pipeline de contenido/imágenes ya dominado |
| 3 | Números de emergencia por país + LLAMAR | Esfuerzo mínimo, impacto alto |
| 4 | Calculadoras OMS (dosis, SRO, cloro) | Lógica pura, bajo esfuerzo |
| 5 | Voz manos libres + metrónomo en guía | Reusa contenido existente |
| 6 | Timer torniquete + tarjeta de herido | Depende de mesh (listo) |
| 7 | Ficha médica ICE + QR | Reusa QR/mesh |
| 8 | Árbol de decisión 911 | Curaduría cuidadosa de contenido |
| 9 | Mapa táctico compartido por mesh | Conecta overlays↔mesh |
| 10 | Punto de encuentro familiar | Depende de 9 (overlays por mesh) |
| 11 | Ultra-ahorro SOS + último beacon | Integra battery_saver+mesh |

Cada fase se implementa con TDD, commit por tarea, y la suite completa verde
antes de pasar a la siguiente. Una fase = software funcionando.

## Fase 1 — Clips de voz por mesh (diseño)

**Objetivo:** mantener presionado el micrófono en el chat → clip de hasta 10 s
→ viaja por el mesh (LAN/BLE/WiFi Direct) cifrado como cualquier mensaje →
el receptor lo reproduce con un toque. Sin internet.

**Protocolo:**
- Nuevo `MeshType.voice` AL FINAL del enum (índice 6). Compatibilidad: las
  versiones viejas descartan tipos desconocidos (`typeIdx >=
  MeshType.values.length → null` en mesh_envelope.dart:118) sin romperse.
- Payload JSON: `{'a': <base64 AAC>, 'd': <durMs>, 'c': 'm4a'}`. 10 s de AAC
  mono 24 kbps ≈ 30 KB → ~40 KB en base64 → bajo el límite de fragmentación
  BLE existente (~64 KB por datagrama, frag.dart) y de UDP.
- Límite duro de grabación: 10 s (corta sola). Reutiliza broadcast + ACK +
  store-and-forward existentes sin cambios.

**Grabación:** paquete `record` (AAC .m4a en iOS/Android/macOS/Windows).
**Reproducción:** `just_audio` (ya es dependencia). Los bytes recibidos se
escriben a `<mesh>/voice/<msgId>.m4a` y se reproducen desde archivo.

**UI (mesh_page / chat):** botón de micrófono junto al campo de texto —
mantener presionado graba (indicador rojo + contador), soltar envía, deslizar
fuera cancela. Burbuja de voz: ▶️ + duración + ✓/✓✓ (ACKs existentes).

**Permisos:** iOS/macOS `NSMicrophoneUsageDescription` (+ entitlement
`com.apple.security.device.audio-input` en macOS), Android `RECORD_AUDIO`
(runtime request vía el paquete record).

**Errores:** sin permiso de micrófono → el botón explica cómo darlo (patrón
asistente); clip que excede el tamaño → se recorta a 10 s por diseño; fallo
de reproducción → icono de error en la burbuja, nunca crash.

**Tests:** codec del payload (base64 round-trip, límite de tamaño), tipo
nuevo compatible (decode de envelope voice), persistencia del archivo,
widget test de la burbuja. La grabación real requiere micrófono físico —
prueba manual en la matriz de dispositivos.

## Fase 2 — Guías de supervivencia (diseño)

Nuevas guías ES + EN en `assets/emergency_guides/{es,en}/` (se auto-cargan
del AssetManifest; sin registro adicional):

1. `balsa_improvisada` — balsa de troncos/bidones, flotación, amarres, qué
   NO hacer en el agua (pedido explícito del usuario).
2. `refugio_naturaleza` — refugio en el monte: lean-to, choza de escombros,
   aislamiento del suelo, dónde NO armar el refugio (pedido explícito).
3. `fuego_supervivencia` — fuego sin fósforos: ferrocerio, lupa, fricción,
   yesca, protección del viento/lluvia, seguridad.
4. `nudos_supervivencia` — los 5 nudos que salvan vidas (as de guía, ballestrinque,
   pescador doble, tensor, presilla), cuándo usar cada uno.
5. `cruce_rios` — evaluar corriente/profundidad, técnica del bastón, cruce
   en grupo, qué hacer si te arrastra; cuándo NO cruzar.
6. `pesca_trampas_supervivencia` — comida de emergencia: pesca improvisada,
   trampas simples, qué es seguro comer (regla universal de comestibilidad
   NO — solo fuentes seguras).

Mismo formato frontmatter (title/keywords/priority) + tablas ❌/✅ que la
CriticalStepsCard ya parsea. Imágenes con el pipeline gpt-image-2 verificado:
fotorrealista para objetos/manos (balsa, nudos, yesca, trampa), ilustración
si el intento foto sale derretido. Alt-text en emergency_guide_media.dart.
Tests existentes cubren automáticamente las guías nuevas (iteran el
manifest: cero $1, cero **, imagen decodificable).

## Fases 3-11

Se especifican en detalle al llegar a cada una (una fase = un plan). El
orden puede ajustarse por pedido del usuario.
