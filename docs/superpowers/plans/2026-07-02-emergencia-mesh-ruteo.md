# Emergencia + Mesh + Ruteo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ruteo que respeta accesos (privadas/oneway/portones/zonas de riesgo), malla de comunicación offline por LAN (chat/SOS/posiciones, canales AES), y guías de emergencia propias ES/EN con modo emergencia de la IA — Android y macOS al 100%.

**Architecture:** Tres módulos casi independientes sobre la app existente: (1) `roads_router.dart` gana perfiles y restricciones en la construcción del grafo; (2) módulo nuevo `lib/modules/mesh/` con sobre binario cifrado + transportes enchufables (fase 1: UDP LAN) + router de malla con dedup/relevo/cola; (3) módulo nuevo `lib/modules/emergency/` con guías markdown embebidas en assets, buscador, y modo estricto/RAG en la IA. Spec: `docs/superpowers/specs/2026-07-02-emergencia-mesh-ruteo-design.md`.

**Tech Stack:** Flutter/Dart puro; `cryptography` (AES-256-GCM), `qr_flutter` (mostrar QR), `RawDatagramSocket` (UDP multicast+broadcast), MethodChannel Kotlin para MulticastLock en Android. Sin servidores.

---

### Task 0: Dependencias y permisos de plataforma

**Files:**
- Modify: `pubspec.yaml` (deps + assets)
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/**/MainActivity.kt`

- [ ] Añadir a pubspec: `cryptography: ^2.7.0`, `qr_flutter: ^4.1.0`; assets: `assets/emergency_guides/es/`, `assets/emergency_guides/en/`.
- [ ] Manifest: `<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>` y `ACCESS_WIFI_STATE`.
- [ ] MainActivity.kt: MethodChannel `prepper/multicast` con `acquire`/`release` de `WifiManager.MulticastLock` (setReferenceCounted(false)). Dart lo llama al iniciar/parar la malla; en no-Android la llamada se ignora con try/catch.
- [ ] `flutter pub get` limpio. Commit.

### Task 1: Ruteo — reglas por perfil (TDD sobre grafo sintético)

**Files:**
- Modify: `lib/modules/maps/roads_router.dart`
- Test: `test/roads_router_rules_test.dart`

API nueva (compatibilidad: parámetros opcionales):
```dart
enum RouteProfile { vehicle, walk }
class RouteRestrictions {
  const RouteRestrictions({this.barriers = const [], this.riskZones = const []});
  final List<LatLng> barriers;          // portones marcados
  final List<List<LatLng>> riskZones;   // polígonos
}
// route(..., {RouteProfile profile = RouteProfile.vehicle,
//             RouteRestrictions restrictions = const RouteRestrictions(),
//             bool ignoreRestrictions = false})
// RouteResult gana: final bool restricted; (false si vino del fallback)
```

Reglas al construir aristas (edge attrs leídos del tile: `kind_detail` con fallback `kind`, `access`, `oneway`):
- `access` ∈ {private, no} → excluida salvo que un extremo esté a <400 m del origen o del destino.
- vehicle: `kind_detail` ∈ {footway, steps, path, pedestrian, sidewalk, crossing, cycleway} → excluida; `track` → peso ×3; `oneway` truthy ('yes','1','true',1) → solo dirección A→B (no se añade B→A).
- walk: todo permitido, oneway ignorado.
- Portón: excluida si algún extremo o el punto medio está a <15 m de un barrier.
- Zona de riesgo: peso ×10 si el punto medio cae dentro del polígono (ray casting `_pointInPolygon`).
- El stitching (<20 m) NO conecta a través de aristas excluidas (se cose después del filtrado, igual que hoy — solo une nodos existentes).

- [ ] Escribir tests con grafo sintético (sin .pmtiles): construir con un helper visible para test `RoadRouter.buildGraphForTest(edges: [...])`… **Alternativa más simple y elegida:** extraer la lógica de decisión a funciones puras y testear esas:
```dart
// en roads_router.dart (públicas para test):
class EdgeAttrs { final String? kindDetail; final String? access; final bool oneway; }
double? edgeMultiplier(EdgeAttrs a, RouteProfile p) // null = excluida, 1.0 normal, 3.0 track-vehicle
bool onewayBlocksReverse(EdgeAttrs a, RouteProfile p)
bool nearAnyBarrier(LatLng a, LatLng b, List<LatLng> barriers) // <15m
bool insideAnyZone(LatLng mid, List<List<LatLng>> zones)
```
Tests: private→null salvo grace (la grace se testea vía `route()` en Task 2 con mapa real); footway vehicle→null, walk→1.0; track vehicle→3.0; oneway vehicle bloquea reversa, walk no; barrier a 10m→true, a 30m→false; punto dentro/fuera de polígono.
- [ ] Verlos fallar (`flutter test test/roads_router_rules_test.dart`).
- [ ] Implementar las funciones y cablearlas en la construcción del grafo (aristas dirigidas: `_addEdge` gana parámetro `bidirectional`).
- [ ] Fallback en `route()`: si status noPath y !ignoreRestrictions → reintenta con ignoreRestrictions:true y marca `restricted:false`.
- [ ] Tests verdes. `flutter analyze` limpio. Commit.

### Task 2: Ruteo — UI (perfil, portones, advertencia) + mapa real

**Files:**
- Modify: `lib/modules/maps/map_overlays.dart` (OverlayKind.barrier "Portón/Barrera", icono `Icons.block`, color rojo oscuro)
- Modify: `lib/modules/maps/maps_page.dart`
- Test: `test/roads_router_test.dart` (ampliar)

- [ ] `OverlayKind.barrier` + label/icono/color + aparece en `_AddPointSheet`.
- [ ] maps_page: estado `_profile` (default vehicle); FAB pequeño toggle 🚗/🚶 visible cuando hay destino; `_computeRoute()` pasa profile + `RouteRestrictions(barriers: overlays barrier, riskZones: overlays riskZone.points)`; si `result.restricted == false` → snackbar naranja "⚠️ Sin ruta limpia: esta ruta puede cruzar zonas restringidas". Readout muestra 🚗/🚶.
- [ ] Ampliar test de mapa real: la ruta 🚗 entre los dos puntos de SPS no debe usar aristas `access=private` fuera de la gracia (asserta que status ok y restricted true).
- [ ] Tests + analyze verdes. Commit.

### Task 3: Mesh — sobre binario + cifrado (TDD)

**Files:**
- Create: `lib/modules/mesh/mesh_envelope.dart`
- Create: `lib/modules/mesh/mesh_channel.dart`
- Test: `test/mesh_envelope_test.dart`

```dart
// mesh_channel.dart
class MeshChannel {
  final String name; final Uint8List key; // 32 bytes
  String get id; // hex de los primeros 4 bytes de sha256(name + key) — 8 chars
  String toCode(); // 'PPMESH1:' + base64Url('$name\n${hex(key)}')
  static MeshChannel? fromCode(String code);
  static MeshChannel create(String name); // clave aleatoria segura
  static final MeshChannel emergency; // name 'EMERGENCIA', key = 32 bytes 0x00, id fijo; SIN cifrar
  bool get isEmergency;
}

// mesh_envelope.dart — binario little-endian:
// magic 'PM01'(4) msgId(8) channelIdRaw(4) senderId(8) type(1) hopLimit(1)
// tsMillis(8) nameLen(1)+utf8 payloadLen(2)+payload
enum MeshType { chat, position, sos, sosCancel, ack, beacon }
class MeshEnvelope { ... encode(); static MeshEnvelope? decode(Uint8List); }
// Cifrado payload (AES-256-GCM, package:cryptography):
Future<Uint8List> sealPayload(Map<String,dynamic> json, MeshChannel ch); // emergencia: utf8 json plano
Future<Map<String,dynamic>?> openPayload(Uint8List data, MeshChannel ch); // null si no descifra
```

- [ ] Tests: (a) encode→decode round-trip preserva todos los campos; (b) decode de basura/magic malo → null; (c) seal→open round-trip en canal cifrado; (d) open con clave equivocada → null; (e) canal emergencia: payload legible sin clave; (f) toCode→fromCode round-trip; (g) dos create() → claves distintas.
- [ ] Ver fallar → implementar → verdes. Commit.

### Task 4: Mesh — router de malla (dedup, relevo, cola) con transporte falso (TDD)

**Files:**
- Create: `lib/modules/mesh/mesh_transport.dart`
- Create: `lib/modules/mesh/mesh_router.dart`
- Create: `lib/modules/mesh/mesh_store.dart`
- Test: `test/mesh_router_test.dart`

```dart
// mesh_transport.dart
abstract class MeshTransport {
  String get name;
  Future<void> start(); Future<void> stop();
  Future<void> send(Uint8List datagram);
  Stream<Uint8List> get onData;
  bool get hasPeers; // LAN: peers con beacon reciente
}
class FakeTransport implements MeshTransport { /* buffers en memoria, inyectar datagramas */ }

// mesh_router.dart
class MeshRouter {
  MeshRouter({required this.identity, required List<MeshTransport> transports,
              required List<MeshChannel> channels, required MeshStore store});
  final _seen = <int>{}; final _seenQueue = Queue<int>(); // LRU cap 500
  Stream<MeshEvent> get events; // decoded+decrypted, con channel y tipo
  Future<void> broadcast(MeshEnvelope env); // encode → todos los transportes; encola si !hasPeers
  // al recibir: decode → seen? skip : mark; relay si hopLimit>0 (hopLimit-1, mismo msgId);
  // canal conocido o emergencia → openPayload → emit + store.append
  Future<void> flushOutbox(); // llamado al aparecer peers
}
```

- [ ] Tests con FakeTransport y store en dir temporal: (a) mensaje propio difundido llega codificado al transporte; (b) datagrama entrante emite MeshEvent con payload descifrado; (c) el mismo msgId dos veces → un solo evento; (d) entrante con hopLimit 2 → se re-difunde con hopLimit 1; con hopLimit 0 → no se re-difunde; (e) canal desconocido → no emite evento pero SÍ releva; (f) sin peers → broadcast queda en outbox; al `flushOutbox` con peers → sale por el transporte; (g) los mensajes se persisten (JSONL) y `MeshStore.load` los recupera.
- [ ] Ver fallar → implementar (store: `~/PrepperPad/mesh/<channelId>.jsonl` + `outbox.json`; en tests, dir inyectable) → verdes. Commit.

### Task 5: Mesh — transporte LAN real + integración loopback

**Files:**
- Create: `lib/modules/mesh/lan_transport.dart`
- Test: `test/lan_transport_test.dart`

```dart
class LanTransport implements MeshTransport {
  // bind RawDatagramSocket(InternetAddress.anyIPv4, 47777, reuseAddress: true, reusePort: true)
  // joinMulticast(InternetAddress('239.255.77.77')); broadcastEnabled = true;
  // send(): a multicast y a 255.255.255.255 (ambos best-effort, try/catch)
  // beacon propio cada 15s (MeshType.beacon, canal emergencia, payload {n: nombre});
  // peers: Map<senderId, DateTime> — hasPeers = alguno con beacon < 45s;
  // (los beacons los construye MeshService; el transporte solo transporta.
  //  El registro de peers vive en MeshRouter al ver type==beacon.)
  // Android: MethodChannel('prepper/multicast').invokeMethod('acquire') en start().
}
```
Nota de diseño: `hasPeers`/beacons se gestionan en `MeshRouter` (ve todos los transportes); `MeshTransport.hasPeers` se elimina de la interfaz si complica — decisión final en implementación, los tests de Task 4 se ajustan con la que quede.

- [ ] Test integración (solo escritorio/CI): dos LanTransport en el MISMO host (reusePort) — A.send(bytes) → B.onData lo recibe (multicast loopback habilitado: `socket.multicastLoopback = true`). Timeout 10 s con skip si el runner no permite multicast (`markTestSkipped`).
- [ ] Implementar → verde local en macOS. Commit.

### Task 6: Mesh — servicio (identidad, canales, beacons, posiciones, SOS)

**Files:**
- Create: `lib/modules/mesh/mesh_identity.dart` (deviceId 8B hex + nombre; JSON en `~/PrepperPad/mesh/identity.json`)
- Create: `lib/modules/mesh/mesh_service.dart` (singleton; API de la UI)
- Create: `lib/modules/mesh/position_store.dart` (`ValueNotifier<Map<String, PeerPosition>>`)
- Test: `test/mesh_service_test.dart`

```dart
class MeshService {
  static final instance = MeshService._();
  Future<void> start(); Future<void> stop(); // start: identity+channels+LanTransport+router
  List<MeshChannel> get channels; Future<void> joinChannel(MeshChannel c); Future<void> leaveChannel(String id);
  Future<void> sendChat(MeshChannel c, String text);
  Stream<MeshEvent> get events;
  // SOS: startSos(note) → timer 60s difunde MeshType.sos en emergencia con GPS+batería(?)—batería omitida v1;
  // cancelSos() difunde sosCancel y para el timer. ValueNotifier<bool> sosActive.
  // Posiciones: setShareLocation(bool, MeshChannel) → LocationService.stream(distanceFilter:50)
  //   + timer 2min → MeshType.position al canal. Entrantes → PositionStore.
  // Beacon: timer 15s → MeshType.beacon en emergencia {n: nombre}.
  // Persistencia canales: ~/PrepperPad/mesh/channels.json
}
```
- [ ] Tests (con FakeTransport inyectable en MeshService para test): sendChat produce evento local y se persiste; posición entrante actualiza PositionStore; sos entrante emite evento sos; canales se guardan y recargan.
- [ ] Implementar → verdes. Commit.

### Task 7: Mesh — UI (pestaña Comunicación)

**Files:**
- Create: `lib/modules/mesh/mesh_page.dart`
- Modify: `lib/app_shell.dart` (o donde viva la NavigationRail — localizar con grep 'Depósito')

- [ ] Pestaña "Comunicación" (icono `Icons.cell_tower`) entre Mapas y Notas.
- [ ] Primera vez: pedir nombre del dispositivo (TextField) → MeshIdentity.
- [ ] Vista canales: lista (nombre, último mensaje, no-leídos) + "Crear canal" (nombre → genera clave → muestra QR con `QrImageView` + código copiable) + "Unirse" (pegar código).
- [ ] Vista chat: mensajes burbuja (yo/otros con nombre), input, indicador "en cola" si sin peers; encabezado muestra peers presentes (beacons <45 s).
- [ ] Botón SOS: rojo grande, siempre visible arriba; confirmación → nota opcional → activa (banner rojo pulsante "SOS ACTIVO — difundiendo cada 60 s" + botón "Estoy a salvo").
- [ ] SOS entrante (de events, en el shell o mesh_page): diálogo rojo a pantalla completa con nombre, distancia/rumbo (LocationService), botón "Ver en mapa" y `SystemSound`.
- [ ] analyze limpio; smoke test manual mac. Commit.

### Task 8: Mesh — integración con Mapas

**Files:**
- Modify: `lib/modules/maps/maps_page.dart`

- [ ] Escuchar `PositionStore`: marcador azul-verde con inicial del nombre por cada peer (<15 min de antigüedad).
- [ ] SOS activo entrante: pin rojo pulsante en su posición; tocar → distancia/rumbo.
- [ ] Botón "Ver en mapa" del diálogo SOS navega a Mapas centrado en esa posición (callback vía shell o simple: setState + move).
- [ ] analyze + tests verdes. Commit.

### Task 9: Guías de Emergencia — contenido ES (ultra-detallado)

**Files:**
- Create: `assets/emergency_guides/es/*.md` (12 guías)

Guías (nombres de archivo): `rcp_adulto.md`, `rcp_nino_bebe.md`, `atragantamiento.md`, `hemorragia_severa.md`, `shock.md`, `quemaduras.md`, `fracturas_inmovilizacion.md`, `trauma_cabeza_columna.md`, `infarto_acv.md`, `convulsiones.md`, `hipotermia_golpe_calor.md`, `parto_emergencia.md`, `mordeduras_picaduras.md`, `intoxicaciones.md`, `triaje_multivictima.md`, `botiquin.md` (16 total).

Estructura OBLIGATORIA por guía (frontmatter YAML + secciones):
```markdown
---
title: RCP en adultos
keywords: [rcp, paro, corazon, no respira, inconsciente, reanimacion, compresiones]
priority: 1
---
# RCP en adultos
> ⚠️ Esta guía no sustituye atención médica profesional. Busca ayuda en cuanto sea posible.
## Cuándo sospecharlo …
## Qué NO hacer …
## Pasos (numerados, medibles: frecuencia 100-120/min, profundidad 5-6 cm, 30:2…) …
## Cuándo buscar ayuda / trasladar …
## Señales de deterioro …
```
Requisitos: consenso científico publicado, cero menciones a cursos/marcas registradas, lenguaje "para dummies" (frases cortas, imperativas), medidas concretas SIEMPRE (tiempos, profundidades, proporciones, dosis solo OTC genéricas con "lee la etiqueta").
- [ ] Escribir las 16 guías. Commit (uno solo para ES).

### Task 10: Guías — contenido EN

- [ ] Create: `assets/emergency_guides/en/*.md` — las mismas 16, en inglés (traducción fiel, keywords en inglés). Commit.

### Task 11: Módulo Emergencia — loader, búsqueda, UI (TDD en lógica)

**Files:**
- Create: `lib/modules/emergency/emergency_guides.dart`
- Create: `lib/modules/emergency/emergency_page.dart`
- Modify: shell (pestaña "Emergencia", icono `Icons.emergency`, ROJA, primera tras Inicio)
- Test: `test/emergency_guides_test.dart`

```dart
class EmergencyGuide { final String id, lang, title, body; final List<String> keywords; final int priority; }
class EmergencyGuides {
  static Future<List<EmergencyGuide>> load(String lang); // AssetManifest + parse frontmatter
  static List<EmergencyGuide> search(List<EmergencyGuide> all, String query);
  // scoring: keyword exacto 10, keyword parcial 5, título 8/4, cuerpo 1 por hit; orden desc, luego priority
}
```
- [ ] Tests: cargan 16 guías es y 16 en; frontmatter parseado; search('no respira') → rcp_adulto primero; search('sangrado') → hemorragia; search('') → todas por priority.
- [ ] Implementar → verdes.
- [ ] UI: grid de botones grandes (icono + título), buscador arriba ("¿Qué está pasando?"), selector idioma (es/en, default es), viewer con el pipeline markdown de Notas (markdown→HTML→flutter_widget_from_html_core), texto grande. Banner disclaimer.
- [ ] Commit.

### Task 12: IA — modo emergencia (estricto en Android, RAG en desktop)

**Files:**
- Modify: `lib/modules/ai/*` (localizar LibraryRetriever y chat page con grep)
- Test: `test/emergency_ai_test.dart`

- [ ] `LibraryRetriever` (o wrapper nuevo `EmergencyRetriever`): busca PRIMERO en EmergencyGuides (ambos idiomas, prioriza el del locale), luego ZIMs médicos; devuelve fuentes etiquetadas.
- [ ] Toggle "🚨 Emergencia" en el chat: system prompt especializado (responde en pasos numerados accionables; seguridad de escena primero; cita [n]; termina con "busca ayuda médica profesional"), temperatura baja.
- [ ] Si llama-server NO disponible (Android hoy): el envío en modo emergencia responde con las secciones de la(s) guía(s) top (título + pasos completos) y nota "Respuesta directa de las guías (IA local no instalada)". Cero generación.
- [ ] Test: modo estricto con query 'no respira' devuelve texto que contiene 'compresiones' y referencia a la guía.
- [ ] analyze + tests verdes. Commit.

### Task 13: Fix Esenciales

**Files:**
- Modify: `lib/modules/depot/download_manager.dart` (ChangeNotifier/stream de completados si no existe)
- Modify: `lib/modules/library/library_page.dart` (escuchar y refrescar)
- Modify: `lib/modules/library/zim_web_reader_page.dart` y `zim_reader_page.dart` (pantalla de error con "Reintentar")

- [ ] Al completarse una descarga (rename .part→.zim) → notificar; library_page refresca su lista si está montada.
- [ ] Lector: si `_open()` falla → UI de error clara con botón Reintentar (re-ejecuta `_open`).
- [ ] Commit.

### Task 14: Verificación total + release v0.2.0

- [ ] `flutter analyze` → 0 issues; `flutter test` → todo verde.
- [ ] `./scripts/package_macos.sh`; abrir DOS instancias (`open -n`) → crear canal en A, unirse por código en B, chat A↔B, SOS en A visible en B con alerta, posiciones en mapa. Ruta 🚗 vs 🚶 difieren; portón corta ruta.
- [ ] Actualizar `docs/INSTALACION.md` (sección Comunicación + Emergencia) y README estado por plataforma.
- [ ] Commit final; bump `version: 0.2.0`; push + tag `v0.2.0`; CI: macOS y Android verdes obligatorios (5/5 deseable); release con .dmg + .apk.
- [ ] Actualizar memoria del proyecto.
