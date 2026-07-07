# Apple + Android listo para tiendas: mesh multiplataforma — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline — RAM limitada en esta máquina, sin subagentes). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mesh iPhone↔Android por WiFi (Bonjour+unicast) y BLE doble-rol, ruteo escalable a ~50 nodos, target iOS conforme a App Store, builds de tienda sin auto-actualización.

**Architecture:** Los transportes cumplen el contrato `MeshTransport` existente; el router ya puentea entre ellos. Se agrega: capa de fragmentación pura para BLE, supresión de inundación con jitter en el router, descubrimiento Bonjour que siembra el unicast del `LanTransport`, y un `BleTransport` reescrito sobre `bluetooth_low_energy` (central+periférico). iOS se crea con `flutter create`, permisos honestos y zstd estático.

**Tech Stack:** Flutter/Dart, bonsoir (NSD/Bonjour), bluetooth_low_energy (GATT dual-rol), cmake para zstd iOS.

**Regla de la casa:** cada task termina con `flutter analyze` limpio + suite verde + commit. Español en UI, inglés en código.

---

### Task 1: Fragmentación BLE (Dart puro)

**Files:**
- Create: `lib/modules/mesh/frag.dart`
- Test: `test/frag_test.dart`

BLE mueve ~180 bytes útiles/notificación; los sobres miden 200–600. Formato de
fragmento (little-endian): `[u32 fragId][u16 seq][u16 total][payload…]`.
`fragId` aleatorio por mensaje. Reensamblador con timeout 10s y tope de 16
mensajes en vuelo (LRU) para no crecer sin límite.

- [ ] **Step 1: test que falla** — `test/frag_test.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/frag.dart';

void main() {
  test('mensaje corto viaja en un solo fragmento y se rearma', () {
    final msg = Uint8List.fromList(List.generate(100, (i) => i));
    final frags = fragment(msg, mtu: 185);
    expect(frags, hasLength(1));
    final rx = Reassembler();
    expect(rx.accept(frags.single), equals(msg));
  });

  test('mensaje largo se parte y se rearma en cualquier orden', () {
    final msg = Uint8List.fromList(List.generate(1000, (i) => i % 251));
    final frags = fragment(msg, mtu: 185);
    expect(frags.length, greaterThan(1));
    final rx = Reassembler();
    Uint8List? out;
    // Entregar en orden inverso: solo el último accept devuelve el mensaje.
    for (final f in frags.reversed) {
      out = rx.accept(f) ?? out;
    }
    expect(out, equals(msg));
  });

  test('fragmento perdido → nada; mensajes intercalados no se mezclan', () {
    final a = Uint8List.fromList(List.filled(500, 7));
    final b = Uint8List.fromList(List.filled(500, 9));
    final fa = fragment(a, mtu: 185);
    final fb = fragment(b, mtu: 185);
    final rx = Reassembler();
    expect(rx.accept(fa[0]), isNull);
    expect(rx.accept(fb[0]), isNull);
    expect(rx.accept(fb[1]), isNull);
    expect(rx.accept(fa[1]), isNull);
    final outB = rx.accept(fb[2]);
    expect(outB, equals(b));
    // a sigue incompleto (le falta fa[2]) — no devuelve nada ni corrompe.
    expect(rx.accept(fa[2]), equals(a));
  });

  test('basura corta no revienta', () {
    final rx = Reassembler();
    expect(rx.accept(Uint8List(3)), isNull);
  });
}
```

- [ ] **Step 2:** `flutter test test/frag_test.dart` → FALLA (no existe frag.dart)
- [ ] **Step 3: implementación** — `lib/modules/mesh/frag.dart`:

```dart
// BLE fragmentation: envelopes exceed a single GATT write (~180 usable
// bytes), so they are split into [u32 fragId][u16 seq][u16 total][chunk]
// frames and reassembled on the far side. Pure Dart, transport-agnostic.
import 'dart:math';
import 'dart:typed_data';

const int fragHeaderLen = 8;

List<Uint8List> fragment(Uint8List message, {required int mtu}) {
  final chunk = mtu - fragHeaderLen;
  assert(chunk > 0);
  final fragId = Random().nextInt(0xFFFFFFFF);
  final total = (message.length / chunk).ceil().clamp(1, 0xFFFF);
  final out = <Uint8List>[];
  for (var seq = 0; seq < total; seq++) {
    final start = seq * chunk;
    final end = min(start + chunk, message.length);
    final frame = Uint8List(fragHeaderLen + end - start);
    final bd = ByteData.sublistView(frame);
    bd.setUint32(0, fragId, Endian.little);
    bd.setUint16(4, seq, Endian.little);
    bd.setUint16(6, total, Endian.little);
    frame.setRange(fragHeaderLen, frame.length, message, start);
    out.add(frame);
  }
  return out;
}

class _Partial {
  _Partial(this.total) : parts = List<Uint8List?>.filled(total, null);
  final int total;
  final List<Uint8List?> parts;
  final DateTime started = DateTime.now();
  int have = 0;
}

/// Rebuilds messages from fragments. Bounded memory: at most [maxInFlight]
/// partial messages, each abandoned after [timeout].
class Reassembler {
  Reassembler({this.timeout = const Duration(seconds: 10), this.maxInFlight = 16});
  final Duration timeout;
  final int maxInFlight;
  final _partials = <int, _Partial>{};

  Uint8List? accept(Uint8List frame) {
    if (frame.length < fragHeaderLen) return null;
    final bd = ByteData.sublistView(frame);
    final fragId = bd.getUint32(0, Endian.little);
    final seq = bd.getUint16(4, Endian.little);
    final total = bd.getUint16(6, Endian.little);
    if (total == 0 || seq >= total) return null;
    _evictStale();
    final p = _partials.putIfAbsent(fragId, () {
      while (_partials.length >= maxInFlight) {
        _partials.remove(_partials.keys.first); // oldest-inserted
      }
      return _Partial(total);
    });
    if (p.total != total) return null; // corrupt/conflicting
    if (p.parts[seq] == null) {
      p.parts[seq] = frame.sublist(fragHeaderLen);
      p.have++;
    }
    if (p.have < p.total) return null;
    _partials.remove(fragId);
    final b = BytesBuilder(copy: false);
    for (final part in p.parts) {
      b.add(part!);
    }
    return b.toBytes();
  }

  void _evictStale() {
    final now = DateTime.now();
    _partials.removeWhere((_, p) => now.difference(p.started) > timeout);
  }
}
```

- [ ] **Step 4:** `flutter test test/frag_test.dart` → PASS
- [ ] **Step 5:** `git add lib/modules/mesh/frag.dart test/frag_test.dart && git commit -m "feat(mesh): capa de fragmentación para BLE"`

### Task 2: Supresión de inundación con jitter (router)

**Files:**
- Modify: `lib/modules/mesh/mesh_router.dart` (método `_handleIncoming`, nuevos campos)
- Test: `test/mesh_router_test.dart` (agregar grupo)

Al recibir sobre ajeno con `hopLimit>0`: contar veces-oído por msgId; agendar
relevo con jitter (SOS 20–80ms umbral 3; resto 50–300ms umbral 2); si el
contador alcanza el umbral antes de disparar, cancelar. Inyectable para test:
`relayJitter(MeshType)` como función reemplazable y umbral por tipo.

- [ ] **Step 1: tests que fallan** — en `test/mesh_router_test.dart` agregar:

```dart
  test('releva con jitter: 1 copia oída → releva al vencer el jitter',
      () async {
    router.debugRelayJitter = (_) => const Duration(milliseconds: 30);
    final env = await makeEnvelope(
        channel: familia, senderId: otherId, hopLimit: 2);
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    // Aún dentro del jitter: no ha relevado (solo procesó localmente).
    expect(
        transport.sent
            .map((b) => MeshEnvelope.decode(b)!)
            .where((e) => e.msgId == env.msgId),
        isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final relayed = transport.sent
        .map((b) => MeshEnvelope.decode(b)!)
        .where((e) => e.msgId == env.msgId)
        .toList();
    expect(relayed, hasLength(1));
    expect(relayed.single.hopLimit, 1);
  });

  test('supresión: oír 2+ copias durante el jitter cancela el relevo',
      () async {
    router.debugRelayJitter = (_) => const Duration(milliseconds: 60);
    final env = await makeEnvelope(
        channel: familia, senderId: otherId, hopLimit: 2);
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    transport.inject(env.encode()); // otro nodo ya lo relevó
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(
        transport.sent
            .map((b) => MeshEnvelope.decode(b)!)
            .where((e) => e.msgId == env.msgId),
        isEmpty,
        reason: 'el relevo debe suprimirse si la red ya lo repitió');
  });

  test('SOS usa umbral 3: dos copias no lo suprimen', () async {
    router.debugRelayJitter = (_) => const Duration(milliseconds: 60);
    final env = await makeEnvelope(
        channel: MeshChannel.emergency,
        senderId: otherId,
        type: MeshType.sos,
        hopLimit: 3,
        payload: {'note': 'x'});
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(
        transport.sent
            .map((b) => MeshEnvelope.decode(b)!)
            .where((e) => e.msgId == env.msgId),
        hasLength(1),
        reason: 'un SOS se releva salvo saturación evidente (3+)');
  });
```

- [ ] **Step 2:** `flutter test test/mesh_router_test.dart` → FALLAN los 3
- [ ] **Step 3: implementación** en `mesh_router.dart`. Campos nuevos junto a `_seen`:

```dart
  // Flood suppression (Meshtastic-style): count copies heard per msgId and
  // schedule the relay after a random jitter; if the network already repeated
  // the message enough times while we waited, our relay adds nothing — cancel.
  final _heardCount = <int, int>{};
  final _pendingRelays = <int, Timer>{};

  /// Test hook: override the relay jitter (production: random per type).
  @visibleForTesting
  Duration Function(MeshType type)? debugRelayJitter;

  Duration _relayJitter(MeshType type) {
    final custom = debugRelayJitter;
    if (custom != null) return custom(type);
    final r = Random();
    return type == MeshType.sos
        ? Duration(milliseconds: 20 + r.nextInt(60))
        : Duration(milliseconds: 50 + r.nextInt(250));
  }

  static int _suppressThreshold(MeshType type) =>
      type == MeshType.sos ? 3 : 2;
```

En `_handleIncoming`, reemplazar el relevo inmediato por:

```dart
    _heardCount[env.msgId] = (_heardCount[env.msgId] ?? 0) + 1;
    if (env.hopLimit > 0 && !_pendingRelays.containsKey(env.msgId)) {
      final relayBytes = env.withHop(env.hopLimit - 1).encode();
      _pendingRelays[env.msgId] = Timer(_relayJitter(env.type), () {
        _pendingRelays.remove(env.msgId);
        if ((_heardCount[env.msgId] ?? 0) < _suppressThreshold(env.type)) {
          _sendAll(relayBytes);
        }
      });
    }
```

Nota: el dedup `_markSeen` sigue cortando el *procesamiento* duplicado, pero el
conteo `_heardCount` debe incrementarse ANTES del `if (!_markSeen…) return;`
(mover `notePeer` y el conteo arriba del dedup). En `stop()`: cancelar todos
los `_pendingRelays`. Podar `_heardCount` con el mismo esquema LRU de `_seen`
(al expulsar de `_seenQueue`, borrar también de `_heardCount`).

- [ ] **Step 4:** `flutter test test/mesh_router_test.dart` → PASS todos (los viejos incluidos; el test de relevo existente "releva con hopLimit-1" debe ajustarse a esperar con `await Future.delayed(350ms)` por el jitter)
- [ ] **Step 5:** `flutter analyze` limpio; commit `feat(mesh): supresión de inundación con jitter — escala ~50 nodos`

### Task 3: Beacons adaptativos (batería)

**Files:**
- Modify: `lib/modules/mesh/mesh_service.dart` (timer de beacon)
- Test: `test/mesh_service_test.dart`

- [ ] **Step 1: test** — el intervalo se decide por actividad:

```dart
  test('beacon adaptativo: 15s con peers, 60s en reposo', () {
    expect(MeshService.beaconInterval(peersNearby: true), 
        const Duration(seconds: 15));
    expect(MeshService.beaconInterval(peersNearby: false),
        const Duration(seconds: 60));
  });
```

- [ ] **Step 2:** FALLA. **Step 3:** en `MeshService`:

```dart
  /// Beacon cadence: fast while others are around (presence freshness),
  /// slow when alone (battery — the radio still wakes for incoming).
  static Duration beaconInterval({required bool peersNearby}) =>
      peersNearby ? const Duration(seconds: 15) : const Duration(seconds: 60);
```

Y el timer periódico fijo de 15s se reemplaza por un `Timer` reprogramado:
al disparar, enviar beacon + reprogramar con
`beaconInterval(peersNearby: router.peers.isNotEmpty)`.

- [ ] **Step 4:** PASS + suite completa verde. **Step 5:** commit `feat(mesh): beacons adaptativos 15s/60s`

### Task 4: Descubrimiento Bonjour (bonsoir) sembrando unicast

**Files:**
- Modify: `pubspec.yaml` (agregar `bonsoir: ^5.1.0`)
- Create: `lib/modules/mesh/lan_discovery.dart`
- Modify: `lib/modules/mesh/lan_transport.dart` (usar el discovery)
- Test: `test/lan_discovery_test.dart`

Diseño: `LanDiscovery` abstrae bonsoir tras una interfaz para poder testear la
lógica sin plataforma. Anuncia `_prepperpad._udp` con TXT `{id, port}` y
navega; por cada peer resuelto llama `onPeer(InternetAddress, int port)`.
`LanTransport.start()` lo arranca y siembra `_peerAddrs` (el mapa unicast que
ya existe); en iOS esto es LA vía (multicast bloqueado sin entitlement).

- [ ] **Step 1: test** de la lógica de resolución (interfaz falsa):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/lan_discovery.dart';

void main() {
  test('un servicio resuelto ajeno dispara onPeer con ip y puerto', () {
    final seen = <(String, int)>[];
    final d = LanDiscovery(
        deviceId: 'yo', port: 47777,
        onPeer: (ip, port) => seen.add((ip, port)));
    d.handleResolved(id: 'otro', ip: '192.168.1.7', port: 47777);
    d.handleResolved(id: 'yo', ip: '192.168.1.5', port: 47777); // yo mismo
    expect(seen, [('192.168.1.7', 47777)]);
  });
}
```

- [ ] **Step 2:** FALLA. **Step 3:** `lan_discovery.dart` con `handleResolved`
  puro (filtra el propio id, invoca onPeer) + `start()/stop()` que crean
  `BonsoirBroadcast`/`BonsoirDiscovery` reales (envueltos en try/catch:
  plataforma sin soporte → degradar en silencio, patrón del proyecto).
  En `LanTransport`: crear `LanDiscovery` en `start()` (pasando el `deviceId`
  del servicio vía constructor nuevo opcional), y en `onPeer` insertar en
  `_peerAddrs`. `stop()` lo detiene.
- [ ] **Step 4:** PASS + `flutter analyze` + suite verde (los tests de socket
  existentes no deben romperse: discovery es opcional/nullable en tests).
- [ ] **Step 5:** commit `feat(mesh): descubrimiento Bonjour → unicast (vía iOS sin entitlement)`

### Task 5: BLE doble-rol con bluetooth_low_energy

**Files:**
- Modify: `pubspec.yaml` (quitar `flutter_blue_plus`, agregar `bluetooth_low_energy: ^6.0.0`)
- Rewrite: `lib/modules/mesh/ble_transport.dart`
- Test: `test/ble_transport_test.dart`

Diseño: conservar el patrón existente `BleLink` (interfaz) + implementación
real. La interfaz crece a doble rol:

```dart
abstract class BleLink {
  bool get available;
  Future<bool> start({required void Function(Uint8List frame) onFrame});
  Future<void> stop();
  Future<void> broadcastFrame(Uint8List frame); // a todos los conectados
  int get mtu; // usable payload por frame (>= 20)
}
```

Implementación real `BluetoothLowEnergyLink`: 
- **Periférico**: `PeripheralManager` anuncia servicio UUID
  `50524550-5045-5250-4144-000000000001` con característica RX
  (writeWithoutResponse) y TX (notify). Al recibir write → `onFrame`.
- **Central**: `CentralManager` escanea ese UUID, conecta, descubre RX/TX,
  se suscribe a TX (→ `onFrame`) y escribe a RX en `broadcastFrame`.
- `BleTransport` (MeshTransport): `send()` = `fragment(datagram, mtu)` →
  `broadcastFrame` por fragmento; `onFrame` → `Reassembler.accept` → `onData`.
  Dedup de sobres ya lo hace el router.
- Test con `FakeBleLink` (en memoria, mtu 40 para forzar fragmentación):
  dos transportes unidos por el fake — un datagrama de 500 bytes enviado por A
  sale entero por `onData` de B.

- [ ] **Step 1: test** (fake link par A/B, datagrama 500B cruza fragmentado)
- [ ] **Step 2:** FALLA. **Step 3:** implementar. **Step 4:** PASS + analyze +
  suite. Smoke en macOS: `flutter build macos --debug` compila.
- [ ] **Step 5:** commit `feat(mesh): BLE doble-rol (iPhone↔Android sin red) con fragmentación`

### Task 6: Target iOS + permisos + privacidad

**Files:**
- Create: `ios/` (flutter create), editar `ios/Runner/Info.plist`, `ios/Podfile`
- Create: `ios/Runner/PrivacyInfo.xcprivacy`
- Modify: `lib/modules/ai/ai_page.dart` (guard iOS)

- [ ] **Step 1:** `flutter create --platforms=ios .` y `ios/Podfile`: `platform :ios, '14.0'`
- [ ] **Step 2:** Info.plist — agregar dentro de `<dict>`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Prepper Pad usa Bluetooth para el chat de emergencia entre tus dispositivos cuando no hay internet.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Prepper Pad se comunica con tus otros dispositivos Prepper Pad en tu red WiFi, sin internet.</string>
<key>NSBonjourServices</key>
<array><string>_prepperpad._udp.</string></array>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Tu posición se usa para mostrarte en el mapa offline y compartirla en un SOS. Nunca sale de tus dispositivos.</string>
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

- [ ] **Step 3:** `PrivacyInfo.xcprivacy` (sin recolección; required-reason
  APIs de plugins: UserDefaults CA92.1, FileTimestamp C617.1, SystemBootTime
  35F9.1, DiskSpace E174.1) — agregar al target Runner vía Xcode project
  (editar `project.pbxproj` con el patrón de recursos existente).
- [ ] **Step 4:** IA en iOS — al inicio de la página de IA:

```dart
    if (Platform.isIOS) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'El asistente de IA local estará disponible en iPhone en una '
            'próxima versión. En tablet Android, Mac y PC ya funciona. '
            'Todo lo demás — mapas, comunicación, biblioteca y guías — '
            'funciona completo en este dispositivo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
```

- [ ] **Step 5:** `flutter build ios --simulator --debug` → compila. Si algún
  plugin rompe iOS (p. ej. `nearby_connections`), moverlo a dependencia
  condicional o stub (WifiDirectTransport ya degrada por `available=false`;
  si el pod no compila, se quita del pubspec y se carga solo en Android vía
  interfaz — decidir en el momento con el error real).
- [ ] **Step 6:** commit `feat(ios): target iOS con permisos honestos y privacy manifest`

### Task 7: zstd estático iOS + Biblioteca ZIM

**Files:**
- Create: `scripts/build_native_ios.sh`
- Create: `ios/native/prepper_native.podspec` (vendored xcframework)
- Modify: `lib/core/zim/zim_native.dart` (o donde viva el `DynamicLibrary.open`) — rama iOS con `DynamicLibrary.process()`
- Modify: `ios/Podfile` (pod local)

- [ ] **Step 1:** script cmake: compilar zstd (fuente ya vendorizada en
  `native/`, misma que macOS) para `iphoneos-arm64` y `iphonesimulator-arm64`,
  `xcodebuild -create-xcframework` → `ios/native/zstd.xcframework`. liblzma:
  enlazar la del SDK de Apple (`-llzma`) — no se compila.
- [ ] **Step 2:** podspec vendored + `pod 'prepper_native', :path => 'native'`
  en el Podfile del Runner; `s.vendored_frameworks = 'zstd.xcframework'`,
  `s.libraries = 'lzma'`.
- [ ] **Step 3:** en el loader FFI: `if (Platform.isIOS) return DynamicLibrary.process();`
- [ ] **Step 4:** `flutter build ios --simulator --debug` compila; test de humo
  en simulador: abrir Biblioteca con `wikipedia_mini.zim` (fixture) y leer un
  artículo.
- [ ] **Step 5:** commit `feat(ios): zstd estático + ZIM funcionando en iPhone`

### Task 8: Builds de tienda (sin auto-actualización)

**Files:**
- Modify: `lib/app.dart` y `lib/modules/depot/depot_page.dart` (gate STORE_BUILD)
- Modify: `lib/main.dart` (no update-check en store build)
- Create: `android/app/src/store/AndroidManifest.xml` (remove REQUEST_INSTALL_PACKAGES si existe en main) — o `tools:node="remove"`
- Test: `test/store_build_test.dart`

- [ ] **Step 1:** constante global en `lib/core/build_flags.dart`:

```dart
/// True when built for App Store / Google Play, where self-updating is
/// forbidden (Apple 2.5.2 / Play policy) — the stores own updates.
const bool kStoreBuild = bool.fromEnvironment('STORE_BUILD');
```

- [ ] **Step 2: test:** `kStoreBuild` es `false` por defecto (los builds
  directos conservan el sistema LAN) + la pestaña App del Depósito se omite
  cuando `kStoreBuild` (widget test del TabBar: 6 tabs vs 5).
- [ ] **Step 3:** gates: Depósito construye la lista de tabs condicionalmente;
  `main.dart` no llama `UpdateService.check()` si `kStoreBuild`; iOS **además**
  fuerza el gate (`kStoreBuild || Platform.isIOS` para la pestaña App —
  en iPhone nunca hay sideload).
- [ ] **Step 4:** suite + analyze verdes. Build de verificación:
  `flutter build appbundle --release --dart-define=STORE_BUILD=true` → `.aab`.
- [ ] **Step 5:** commit `feat(stores): builds de tienda sin auto-actualización (2.5.2)`

### Task 9: Verificación total + binarios + guía de envío

- [ ] **Step 1:** `flutter analyze` + `flutter test` (todo verde), 
  `flutter build macos --debug` + prueba en vivo Mac↔Mac (dos HOME) del chat
  con supresión activa (✓✓ sigue funcionando).
- [ ] **Step 2:** recompilar `.apk` directo (con updates LAN) y `.aab` de
  tienda; `.dmg` macOS. Copiar a `dist/` y Desktop.
- [ ] **Step 3:** `docs/PUBLICAR_TIENDAS.md`: pasos exactos de App Store
  Connect (certificados, ficha, capturas, privacidad "no se recolectan
  datos", envío a revisión, formulario del entitlement multicast) y Play
  Console (ficha, .aab, data safety). Qué hace Claude vs qué firmas tú.
- [ ] **Step 4:** commit + push + actualizar memoria del proyecto.

## Self-review

- Spec §1a Bonjour → Task 4; §1b BLE → Tasks 1+5; §1c supresión/beacons →
  Tasks 2+3; §2 iOS → Tasks 6+7; §3 tiendas → Task 8; §4 firma/TestFlight →
  Task 9 documenta y queda pendiente de sesión del usuario con Xcode (no
  automatizable sin sus credenciales). Sin placeholders; tipos consistentes
  (`BleLink.mtu` usado por `fragment(mtu:)`; `LanDiscovery.handleResolved`
  testeado directo).
