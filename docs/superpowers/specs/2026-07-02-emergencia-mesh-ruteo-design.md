# Diseño: Ruteo con accesos + Prepper Mesh + Guías de Emergencia

Fecha: 2026-07-02 · Estado: aprobado por el usuario en sesión de brainstorming.
Alcance de esta iteración: **Android y macOS al 100%** (las demás plataformas
compilan pero se verifican después).

## Contexto y propósito

Prepper Pad es un producto que se venderá **preinstalado en dispositivos**
(tablet Android de entrada, laptop/mini-PC x86; radio LoRa como accesorio
futuro). Propósito declarado del dueño: *"salvar vidas: que te encuentren en
una emergencia, comunicarte de forma segura, y alertar a todos alrededor"*.

## Mejora 1 — Ruteo que respeta accesos

Los tiles Protomaps ya traen `access` (private/no), `oneway` y `kind_detail`
(verificado en el mapa real de Honduras: 83 aristas private en SPS).

- **Perfiles**: selector 🚗/🚶 junto al botón "Ruta".
  - 🚗: prohíbe footway/steps/path/pedestrian/sidewalk/crossing; aristas
    dirigidas si `oneway`; `track` ×3.
  - 🚶: todo permitido, ignora oneway.
  - Ambos: `access=private/no` prohibido **salvo** en los primeros/últimos
    ~400 m de la ruta (permite salir de tu colonia y entrar a la del destino;
    nunca atravesar una ajena como atajo).
- **Portones**: nuevo punto táctico "Portón/Barrera"; el router corta aristas
  a <15 m de uno. (El basemap no trae barrier nodes — verificado.)
- **Zonas de riesgo**: aristas que las cruzan ×10 (rodear salvo sin
  alternativa).
- **Fallback**: si no hay ruta con restricciones → reintento sin
  restricciones con advertencia "⚠️ cruza zonas restringidas".
- **Tests**: grafo sintético (private excluida, oneway, portón corta, 🚗≠🚶)
  + prueba sobre mapa real.

## Mejora 2 — Prepper Mesh (comunicación offline)

Módulo `lib/modules/mesh/` + pestaña "Comunicación".

- **Identidad**: deviceId aleatorio (8 bytes) + nombre amigable. Sin cuentas.
- **Canales**: nombre + clave AES-256; se comparte por QR (mostrar) y código
  de texto (unirse tecleando/pegando — el escaneo con cámara queda para una
  fase posterior). Canal **EMERGENCIA** fijo, sin cifrar, siempre escuchado
  por toda instalación: un SOS llega a desconocidos cercanos.
- **Sobre** (semántica Meshtastic): version, msgId aleatorio 64-bit,
  channelId (hash), senderId, senderName, type (chat|position|sos|sosCancel|
  ack), hopLimit=3, timestamp, payload AES-256-GCM (EMERGENCIA en claro).
  Binario compacto; el mismo sobre viaja por WiFi/BT/LoRa.
- **Transportes enchufables** (interfaz `MeshTransport`):
  1. **Fase 1 (esta iteración): LAN** — UDP multicast 239.255.77.77:47777 +
     broadcast 255.255.255.255 de respaldo; beacons de presencia cada 15 s.
     Android requiere MulticastLock (MethodChannel en MainActivity) +
     permiso CHANGE_WIFI_MULTICAST_STATE.
  2. Fase 2: BLE (tablet anuncia+escanea; laptop central).
  3. Fase 3: adaptador Meshtastic (BLE/USB → protobufs) para la radio LoRa
     de marca propia (decisión: construir sobre Meshtastic, Apache 2.0).
- **Malla**: re-difusión con hopLimit-1 + caché LRU de msgIds (dedup).
  **Store-and-forward**: cola persistente en `~/PrepperPad/mesh/outbox`;
  se entrega al reaparecer beacons del destinatario. ACK para chat.
  Banner "sin alcance — N mensajes en cola".
- **SOS**: botón rojo; difunde cada 60 s por todos los transportes en
  EMERGENCIA (posición GPS + nota + batería). Receptor: alerta a pantalla
  completa + sonido + pin en mapa + distancia/rumbo. "Estoy a salvo" difunde
  cancelación.
- **Posiciones**: toggle de compartir (cada 2 min o 50 m); miembros del canal
  aparecen con nombre en el módulo Mapas (PositionStore compartido).
- **Persistencia**: historial JSONL por canal en `~/PrepperPad/mesh/`
  (viaja con la biblioteca portable).
- **Tests**: sobre round-trip + vectores AES-GCM, dedup/TTL/relevo con
  transportes falsos, integración de dos nodos por UDP loopback.

## Mejora 3 — Guías de Emergencia + modo emergencia de la IA

Restricción legal del dueño: **no usar nombres de cursos registrados ni sus
manuales**. En su lugar: **guías propias ultra-detalladas** estilo "primeros
auxilios para dummies", basadas en el consenso científico ampliamente
publicado (maniobras y umbrales de conocimiento público), redactadas por
nosotros, **en español e inglés** (más idiomas después).

- **Contenido embebido** en `assets/emergency_guides/{es,en}/*.md`
  (funciona sin descargas, día cero, en Android y macOS). Temas iniciales:
  RCP adulto/niño/bebé, atragantamiento, hemorragia severa y torniquete,
  shock, quemaduras, fracturas e inmovilización, trauma de cabeza/columna,
  reconocer infarto y ACV, convulsiones, hipotermia y golpe de calor,
  deshidratación/diarrea, parto de emergencia, mordeduras/picaduras,
  intoxicaciones, triaje básico multivíctima, botiquín recomendado.
  Estructura fija por guía: cuándo sospechar → qué NO hacer → pasos
  numerados → cuándo buscar ayuda → señales de deterioro.
- **UI**: sección "Guías de Emergencia" con botones grandes de acceso rápido
  (RCP, Atragantamiento, Hemorragia, …) en la pestaña del Asistente IA y
  accesible desde Biblioteca. Render markdown (ya existe en Notas).
- **IA modo emergencia**:
  - macOS/desktop (hay llama-server): RAG obligatorio sobre las guías + ZIMs
    médicos con citas [1] (LibraryRetriever ya existe); prompt de sistema
    especializado (pasos accionables, seguridad de escena primero, "busca
    ayuda médica" siempre presente).
  - Android (sin modelo local aún): **modo estricto** — búsqueda directa
    sobre las guías y ZIMs y muestra del texto fuente, sin generación libre.
    Así el módulo funciona al 100% en Android sin LLM.
  - Disclaimer visible: "No sustituye atención médica profesional".
- **Tests**: las guías cargan e indexan; búsqueda por síntoma encuentra la
  guía correcta; el modo estricto devuelve texto de la fuente.

## Bug Esenciales (workstream 0)

Ambos ZIMs abren bien en macOS (verificado en vivo: portada, artículos,
videos). Causa más probable del reporte: intento de apertura durante la
descarga o lista sin refrescar. Fix: refrescar la Biblioteca automáticamente
al completarse una descarga + botón de reintento en el lector si un ZIM
falla al abrir. Si el fallo fue en la tablet Android, se investigará con el
usuario (pendiente de su confirmación del dispositivo/error).

## Riesgos y decisiones

- Multicast en Android varía por fabricante → beacons también por broadcast
  y unicast directo a peers conocidos.
- BLE de escritorio es débil → LAN cubre laptop↔tablet en fase 1.
- Contenido médico: consenso general, sin marcas; revisar por profesional
  antes de venta comercial (responsabilidad del dueño); disclaimers en app.
- IA pequeña alucina → en Android modo estricto sin generación; en desktop
  exigir citas.

## Criterio de éxito de la iteración

1. `flutter analyze` limpio y tests verdes.
2. macOS verificado en vivo: ruta 🚗 evita calle privada del mapa real;
   chat + SOS entre dos instancias por LAN; guías legibles y buscables.
3. APK de Android compila en CI con permisos correctos; módulos funcionan
   por diseño sin LLM (modo estricto) — verificación en tablet real por el
   usuario.
4. Release etiquetado con instaladores.
