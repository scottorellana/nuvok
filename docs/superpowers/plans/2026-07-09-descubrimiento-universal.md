# Descubrimiento Universal Inteligente — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que cualquier dispositivo Prepper Pad (Android/iOS/macOS/Windows) encuentre a los demás sin internet, y cuando no encuentre a nadie, diagnostique por qué y guíe al usuario con pasos concretos.

**Architecture:** Se conserva `MeshTransport`/`MeshRouter` intactos. Fase 1 agrega salud observable por transporte (`TransportHealth`) alimentada por eventos `{type:'state'}` de los bridges nativos y contadores de pares por transporte en el router. Fase 2 agrega un motor de reglas puro (`ConnectionAdvisor`) + banner/asistente en `mesh_page`. Fase 3 agrega el bridge BLE WinRT para Windows con el mismo protocolo `prepper/ble_mesh`.

**Tech Stack:** Flutter/Dart, Kotlin (Android BLE), Swift (iOS/macOS BLE), C++/WinRT (Windows BLE), flutter_test.

**Spec:** `docs/superpowers/specs/2026-07-09-descubrimiento-universal-design.md`

---

## FASE 1 — Diagnóstico por transporte

### Task 1: TransportHealth (modelo puro)

**Files:**
- Create: `lib/modules/mesh/transport_health.dart`
- Test: `test/transport_health_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/transport_health.dart';

void main() {
  test('TransportHealth copyWith preserva y reemplaza campos', () {
    const h = TransportHealth(name: 'ble', state: TransportState.searching);
    expect(h.peers, 0);
    expect(h.hint, isNull);
    final h2 = h.copyWith(state: TransportState.connected, peers: 3);
    expect(h2.name, 'ble');
    expect(h2.state, TransportState.connected);
    expect(h2.peers, 3);
    // el original no cambia
    expect(h.state, TransportState.searching);
  });

  test('isBlocked identifica estados que necesitan acción del usuario', () {
    const off = TransportHealth(name: 'ble', state: TransportState.off);
    const perm =
        TransportHealth(name: 'ble', state: TransportState.noPermission);
    const ok = TransportHealth(name: 'lan', state: TransportState.searching);
    expect(off.isBlocked, isTrue);
    expect(perm.isBlocked, isTrue);
    expect(ok.isBlocked, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/transport_health_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'transport_health.dart'` (archivo no existe)

- [ ] **Step 3: Write minimal implementation**

```dart
// Salud observable de un transporte del mesh. Los transportes hoy degradan
// en silencio (patrón deliberado: nunca tiran el mesh); esto agrega
// visibilidad — QUÉ transporte está activo, cuántos pares ve y, si no
// funciona, POR QUÉ — para que el Asistente de conexión pueda guiar al
// usuario en vez de dejarlo adivinando.
import 'package:flutter/foundation.dart';

enum TransportState {
  /// Radio apagada por el usuario (ej. Bluetooth off) — accionable.
  off,

  /// El hardware no existe o la plataforma no lo soporta.
  unavailable,

  /// Permiso denegado por el usuario — accionable en ajustes de la app.
  noPermission,

  /// Radio encendida, buscando pares.
  searching,

  /// Al menos un par vivo por este transporte.
  connected,
}

@immutable
class TransportHealth {
  const TransportHealth({
    required this.name,
    required this.state,
    this.peers = 0,
    this.hint,
  });

  /// Nombre del transporte: 'ble', 'lan', 'wifi_direct', 'lora'.
  final String name;
  final TransportState state;

  /// Pares vivos vía este transporte (lo rellena MeshService desde el router).
  final int peers;

  /// Pista corta del problema: 'bluetooth_off', 'no_adapter', 'no_network'…
  final String? hint;

  /// True si el estado requiere una acción del usuario para funcionar.
  bool get isBlocked =>
      state == TransportState.off || state == TransportState.noPermission;

  TransportHealth copyWith({TransportState? state, int? peers, String? hint}) =>
      TransportHealth(
        name: name,
        state: state ?? this.state,
        peers: peers ?? this.peers,
        hint: hint ?? this.hint,
      );
}

/// Transportes que reportan salud. Interfaz separada (no en MeshTransport)
/// para no romper fakes de tests ni transportes que aún no reportan.
abstract class HealthReporting {
  ValueNotifier<TransportHealth> get health;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/transport_health_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/modules/mesh/transport_health.dart test/transport_health_test.dart
git commit -m "feat(mesh): modelo TransportHealth — salud observable por transporte"
```

### Task 2: Router — pares por transporte

**Files:**
- Modify: `lib/modules/mesh/mesh_router.dart` (método `start()` ~línea 102, `_handleIncoming` ~línea 211)
- Test: `test/mesh_router_peers_via_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/mesh_channel.dart';
import 'package:prepper_pad/modules/mesh/mesh_envelope.dart';
import 'package:prepper_pad/modules/mesh/mesh_router.dart';
import 'package:prepper_pad/modules/mesh/mesh_store.dart';
import 'package:prepper_pad/modules/mesh/mesh_transport.dart';

class _FakeTransport implements MeshTransport {
  _FakeTransport(this.name);
  @override
  final String name;
  final incoming = StreamController<Uint8List>.broadcast();
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List datagram) async {}
  @override
  Stream<Uint8List> get onData => incoming.stream;
}

void main() {
  test('peersVia cuenta pares por el transporte que los oyó', () async {
    final dir = await createTempMeshDir();
    final ble = _FakeTransport('ble');
    final lan = _FakeTransport('lan');
    final router = MeshRouter(
      deviceId: 'aa00000000000001',
      transports: [ble, lan],
      channels: [MeshChannel.emergency()],
      store: MeshStore(dir),
    );
    await router.start();

    // Un beacon del par bb… llega por BLE.
    final env = await MeshEnvelope.beacon(
      senderId: 'bb00000000000002',
      channel: MeshChannel.emergency(),
      name: 'Par BLE',
    );
    ble.incoming.add(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(router.peersVia('ble'), 1);
    expect(router.peersVia('lan'), 0);
    expect(router.peersVia('inexistente'), 0);
  });
}
```

Nota: si `MeshEnvelope.beacon` no existe con esa firma, abre `lib/modules/mesh/mesh_envelope.dart` y usa el constructor/factory real para un envelope de tipo beacon del canal emergencia (los tests existentes `test/mesh_router_test.dart` muestran el patrón exacto de construcción — copia de ahí). Igual con `createTempMeshDir`: usa el helper de los tests existentes o `Directory.systemTemp.createTempSync('mesh').path`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mesh_router_peers_via_test.dart`
Expected: FAIL — `The method 'peersVia' isn't defined for the class 'MeshRouter'`

- [ ] **Step 3: Implement**

En `mesh_router.dart`, agrega el campo tras `_peers` (~línea 48):

```dart
  // Pares oídos recientemente POR TRANSPORTE — alimenta TransportHealth.peers
  // para que el banner pueda decir "3 dispositivos por Bluetooth".
  final _peersVia = <String, Map<String, DateTime>>{};
```

En `start()` cambia la suscripción para etiquetar el transporte de origen:

```dart
    for (final t in _transports) {
      // Subscribe BEFORE transport start. BLE/WiFi Direct/LAN fakes and some
      // real stacks can emit discovery/beacon payloads immediately during
      // start(); broadcast streams drop events with no listeners.
      _subs.add(t.onData.listen((d) => _handleIncoming(d, via: t.name)));
      await t.start();
    }
```

En `_handleIncoming`, cambia la firma y registra el origen justo tras validar el sender:

```dart
  Future<void> _handleIncoming(Uint8List datagram, {String? via}) async {
    final env = MeshEnvelope.decode(datagram);
    if (env == null) return;
    if (env.senderId == deviceId) return; // our own flood came back
    if (via != null) {
      (_peersVia[via] ??= <String, DateTime>{})[env.senderId] = DateTime.now();
    }
```

(el resto del método queda igual). Agrega el método público junto a `peers`:

```dart
  /// Pares vivos oídos por un transporte concreto ('ble', 'lan', …).
  int peersVia(String transport) {
    final m = _peersVia[transport];
    if (m == null) return 0;
    final now = DateTime.now();
    m.removeWhere((_, heard) => now.difference(heard) >= peerTimeout);
    return m.length;
  }
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/mesh_router_peers_via_test.dart test/mesh_router_test.dart`
Expected: PASS (el test nuevo y toda la suite existente del router)

- [ ] **Step 5: Commit**

```bash
git add lib/modules/mesh/mesh_router.dart test/mesh_router_peers_via_test.dart
git commit -m "feat(mesh): router cuenta pares por transporte (peersVia)"
```

### Task 3: BLE — estado del adaptador hasta TransportHealth

**Files:**
- Modify: `lib/modules/mesh/ble_transport.dart` (interfaz `BleLink` ~línea 170, `NativeBleMeshLink` ~línea 352, `FlutterBluePlusLink` ~línea 200, `BleTransport` ~línea 465)
- Modify: `test/ble_transport_test.dart` (`_FakeBleLink` ~línea 252)
- Test: casos nuevos en `test/ble_transport_test.dart`

- [ ] **Step 1: Write the failing tests** (añadir al final de `main()` en `test/ble_transport_test.dart`)

```dart
  test('BleTransport reporta salud según el estado del adaptador', () async {
    final link = _FakeBleLink();
    final t = BleTransport(link: link);
    await t.start();
    expect(t.health.value.state, TransportState.searching);

    link.stateCtrl.add('off');
    await Future<void>.delayed(Duration.zero);
    expect(t.health.value.state, TransportState.off);
    expect(t.health.value.hint, 'bluetooth_off');

    link.stateCtrl.add('unauthorized');
    await Future<void>.delayed(Duration.zero);
    expect(t.health.value.state, TransportState.noPermission);

    link.stateCtrl.add('on');
    await Future<void>.delayed(Duration.zero);
    expect(t.health.value.state, TransportState.searching);
    await t.stop();
  });
```

Importa `transport_health.dart` arriba del test file:

```dart
import 'package:prepper_pad/modules/mesh/transport_health.dart';
```

- [ ] **Step 2: Update the fake** — en `_FakeBleLink` agrega:

```dart
  final stateCtrl = StreamController<String>.broadcast();
  @override
  Stream<String> get onAdapterState => stateCtrl.stream;
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/ble_transport_test.dart`
Expected: FAIL — `'onAdapterState' isn't defined` / `'health' isn't defined`

- [ ] **Step 4: Implement**

En `ble_transport.dart`:

1. Import: `import 'transport_health.dart';`

2. En `abstract class BleLink` agrega:

```dart
  /// Cambios del adaptador: 'on' | 'off' | 'unauthorized' | 'unsupported'.
  Stream<String> get onAdapterState;
```

3. En `NativeBleMeshLink` agrega campo y wiring:

```dart
  final _state = StreamController<String>.broadcast();

  @override
  Stream<String> get onAdapterState => _state.stream;
```

y en `_handleEvent`, antes del `switch`, el id puede ser null para eventos de
estado, así que muévelo dentro de los cases existentes y agrega el case nuevo:

```dart
  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    if (type == 'state') {
      final v = event['value'] as String?;
      if (v != null) _state.add(v);
      return;
    }
    final id = event['id'] as String?;
    if (id == null || id.isEmpty) return;
    switch (type) {
      // … cases 'peer' y 'data' existentes sin cambios …
    }
  }
```

4. En `FlutterBluePlusLink` agrega el mapeo desde flutter_blue_plus:

```dart
  @override
  Stream<String> get onAdapterState =>
      FlutterBluePlus.adapterState.map((s) => switch (s) {
            BluetoothAdapterState.on => 'on',
            BluetoothAdapterState.off => 'off',
            BluetoothAdapterState.unauthorized => 'unauthorized',
            BluetoothAdapterState.unavailable => 'unsupported',
            _ => 'off',
          });
```

5. En `BleTransport` agrega el notifier de salud (implementa `HealthReporting`):

```dart
class BleTransport implements MeshTransport, HealthReporting {
  // … constructor y campos existentes …

  @override
  final ValueNotifier<TransportHealth> health = ValueNotifier(
      const TransportHealth(name: 'ble', state: TransportState.unavailable));

  StreamSubscription<String>? _stateSub;
```

En `start()`, tras el early-return de `!available` (que debe fijar la salud) y
al arrancar:

```dart
    if (!available) {
      health.value = health.value
          .copyWith(state: TransportState.unavailable, hint: 'no_adapter');
      return; // no adapter — degrade silently
    }
    _stateSub ??= _link.onAdapterState.listen(_onAdapterState);
    health.value = health.value.copyWith(state: TransportState.searching);
```

Agrega el handler como método privado:

```dart
  void _onAdapterState(String s) {
    health.value = switch (s) {
      'off' => health.value
          .copyWith(state: TransportState.off, hint: 'bluetooth_off'),
      'unauthorized' => health.value.copyWith(
          state: TransportState.noPermission, hint: 'bluetooth_permission'),
      'unsupported' => health.value
          .copyWith(state: TransportState.unavailable, hint: 'no_adapter'),
      _ => health.value.copyWith(
          state: _connected.isEmpty
              ? TransportState.searching
              : TransportState.connected),
    };
  }
```

En los puntos donde `_connected` gana o pierde entradas (conexión establecida
y desconexión — busca `_connected[` y `_connected.remove`), actualiza:

```dart
    health.value = health.value.copyWith(
        state: _connected.isEmpty
            ? TransportState.searching
            : TransportState.connected,
        peers: _connected.length);
```

En `stop()`: `await _stateSub?.cancel(); _stateSub = null;` y
`health.value = health.value.copyWith(state: TransportState.unavailable, peers: 0);`
— usa `off`→no: `unavailable` significa "transporte detenido" aquí; correcto
porque tras stop() el transporte no participa.

- [ ] **Step 5: Run tests**

Run: `flutter test test/ble_transport_test.dart`
Expected: PASS (suite completa del archivo, incluido el test nuevo)

- [ ] **Step 6: Commit**

```bash
git add lib/modules/mesh/ble_transport.dart test/ble_transport_test.dart
git commit -m "feat(mesh): BleTransport reporta TransportHealth desde el estado del adaptador"
```

### Task 4: Bridges nativos emiten eventos de estado

**Files:**
- Modify: `android/app/src/main/kotlin/com/prepperpad/prepper_pad/BleMeshBridge.kt` (método `start` ~línea 110, helper `emit` ~línea 492)
- Modify: `ios/Runner/BleMeshBridge.swift` (`centralManagerDidUpdateState` ~línea 160)
- Modify: `macos/Runner/BleMeshBridge.swift` (mismo delegate — espejo del de iOS)

Sin test de unidad (código nativo); la verificación es compilación + el test
Dart de Task 3 que ya cubre el lado receptor.

- [ ] **Step 1: Kotlin — emitir estado en start y en cambios del adaptador**

En `BleMeshBridge.kt`, dentro de `start(result)` (~línea 110):

```kotlin
        if (!hasBleHardware()) {
            emit(mapOf("type" to "state", "value" to "unsupported"))
            result.success(false)
            return
        }
```

y donde se comprueba `adapter.isEnabled` en `startRadios()` (~línea 157):

```kotlin
        val adapter = manager.adapter ?: run {
            emit(mapOf("type" to "state", "value" to "unsupported"))
            return false
        }
        if (!adapter.isEnabled) {
            emit(mapOf("type" to "state", "value" to "off"))
            return false
        }
        emit(mapOf("type" to "state", "value" to "on"))
```

Para cambios en vivo (usuario apaga BT con la app abierta), agrega un
`BroadcastReceiver` como campo de la clase:

```kotlin
    private val btStateReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(c: android.content.Context?, i: android.content.Intent?) {
            when (i?.getIntExtra(android.bluetooth.BluetoothAdapter.EXTRA_STATE, -1)) {
                android.bluetooth.BluetoothAdapter.STATE_ON ->
                    emit(mapOf("type" to "state", "value" to "on"))
                android.bluetooth.BluetoothAdapter.STATE_OFF ->
                    emit(mapOf("type" to "state", "value" to "off"))
            }
        }
    }
    private var btReceiverRegistered = false
```

Regístralo al final de un `startRadios()` exitoso y anúlalo en `stop()`:

```kotlin
        // en startRadios(), justo antes de return true:
        if (!btReceiverRegistered) {
            activity.registerReceiver(btStateReceiver,
                android.content.IntentFilter(
                    android.bluetooth.BluetoothAdapter.ACTION_STATE_CHANGED))
            btReceiverRegistered = true
        }

        // en stop():
        if (btReceiverRegistered) {
            runCatching { activity.unregisterReceiver(btStateReceiver) }
            btReceiverRegistered = false
        }
```

- [ ] **Step 2: Swift (iOS y macOS) — emitir en centralManagerDidUpdateState**

En AMBOS `BleMeshBridge.swift` (ios/Runner y macos/Runner), el delegate
existente solo loguea; agrega la emisión al inicio del método:

```swift
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("PPMESH central state=%d", central.state.rawValue)
        switch central.state {
        case .poweredOn: emit(["type": "state", "value": "on"])
        case .poweredOff: emit(["type": "state", "value": "off"])
        case .unauthorized: emit(["type": "state", "value": "unauthorized"])
        case .unsupported: emit(["type": "state", "value": "unsupported"])
        default: break
        }
        guard running, central.state == .poweredOn else { return }
        // … resto del método sin cambios …
    }
```

- [ ] **Step 3: Verificar compilación**

Run: `cd ~/prepper-pad && flutter build apk --debug --android-skip-build-dependency-validation 2>&1 | tail -3`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

Run: `flutter build macos --debug 2>&1 | tail -3`
Expected: `✓ Built build/macos/Build/Products/Debug/…app` (esto compila el Swift de macOS; el de iOS comparte el mismo código de delegate y se compila en Fase 2/3 con `flutter build ios --debug --no-codesign`)

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/prepperpad/prepper_pad/BleMeshBridge.kt ios/Runner/BleMeshBridge.swift macos/Runner/BleMeshBridge.swift
git commit -m "feat(mesh): bridges nativos emiten estado del adaptador BLE"
```

### Task 5: LAN, WiFi Direct y LoRa reportan salud

**Files:**
- Modify: `lib/modules/mesh/lan_transport.dart`
- Modify: `lib/modules/mesh/wifi_direct_transport.dart`
- Modify: `lib/modules/mesh/lora_transport.dart`
- Test: `test/transport_health_reporting_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/lan_transport.dart';
import 'package:prepper_pad/modules/mesh/transport_health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LanTransport: unavailable → searching al start → unavailable al stop',
      () async {
    final t = LanTransport(port: 47799); // puerto de prueba, sin deviceId
    expect(t.health.value.state, TransportState.unavailable);
    await t.start();
    expect(t.health.value.state, TransportState.searching);
    await t.stop();
    expect(t.health.value.state, TransportState.unavailable);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/transport_health_reporting_test.dart`
Expected: FAIL — `'health' isn't defined for the class 'LanTransport'`

- [ ] **Step 3: Implement**

`lan_transport.dart` — import `package:flutter/foundation.dart` y
`transport_health.dart`; clase implementa `HealthReporting`:

```dart
class LanTransport implements MeshTransport, HealthReporting {
  // … existente …

  @override
  final ValueNotifier<TransportHealth> health = ValueNotifier(
      const TransportHealth(name: 'lan', state: TransportState.unavailable));
```

En `start()`, tras bind exitoso del socket:
`health.value = health.value.copyWith(state: TransportState.searching);`
Si el bind lanza (catch existente o agrega try/catch alrededor del bind):
`health.value = health.value.copyWith(state: TransportState.unavailable, hint: 'no_network');`
En `stop()`:
`health.value = health.value.copyWith(state: TransportState.unavailable, peers: 0);`

`wifi_direct_transport.dart` — mismo patrón con `name: 'wifi_direct'`:
`unavailable` inicial (hint `'android_only'` cuando `!available`), `searching`
tras un `start()` que arrancó de verdad, `unavailable` en `stop()`.

`lora_transport.dart` — mismo patrón con `name: 'lora'`: `searching` cuando el
driver conectó a la radio, `unavailable` con hint `'no_radio'` cuando no hay
módulo emparejado.

- [ ] **Step 4: Run tests**

Run: `flutter test test/transport_health_reporting_test.dart && flutter test test/ --plain-name lan`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/modules/mesh/lan_transport.dart lib/modules/mesh/wifi_direct_transport.dart lib/modules/mesh/lora_transport.dart test/transport_health_reporting_test.dart
git commit -m "feat(mesh): LAN/WiFi-Direct/LoRa reportan TransportHealth"
```

### Task 6: MeshService agrega la salud de todos los transportes

**Files:**
- Modify: `lib/modules/mesh/mesh_service.dart`
- Test: `test/mesh_service_health_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/mesh_identity.dart';
import 'package:prepper_pad/modules/mesh/mesh_service.dart';
import 'package:prepper_pad/modules/mesh/mesh_transport.dart';
import 'package:prepper_pad/modules/mesh/transport_health.dart';

class _HealthyFake implements MeshTransport, HealthReporting {
  @override
  final String name = 'ble';
  @override
  final ValueNotifier<TransportHealth> health = ValueNotifier(
      const TransportHealth(name: 'ble', state: TransportState.searching));
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List datagram) async {}
  @override
  Stream<Uint8List> get onData => const Stream.empty();
}

class _MuteFake implements MeshTransport {
  @override
  final String name = 'lora';
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List datagram) async {}
  @override
  Stream<Uint8List> get onData => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('transportHealths refleja transportes con y sin HealthReporting',
      () async {
    final dir = Directory.systemTemp.createTempSync('meshsvc').path;
    final svc = MeshService.forTest(
      dirPath: dir,
      transports: [_HealthyFake(), _MuteFake()],
      identity: MeshIdentity.create('Test'),
    );
    await svc.start();
    final healths = svc.transportHealths.value;
    expect(healths, hasLength(2));
    expect(healths.firstWhere((h) => h.name == 'ble').state,
        TransportState.searching);
    // El transporte sin HealthReporting aparece como searching genérico
    // (está arrancado) para que el asistente lo cuente.
    expect(healths.firstWhere((h) => h.name == 'lora').state,
        TransportState.searching);
    await svc.stop();
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/mesh_service_health_test.dart`
Expected: FAIL — `'transportHealths' isn't defined`

- [ ] **Step 3: Implement** en `mesh_service.dart`

Imports: `import 'transport_health.dart';`

Campos nuevos junto a `peerCount`:

```dart
  /// Salud agregada de todos los transportes, con pares por transporte.
  /// La UI (banner + asistente) observa esto.
  final ValueNotifier<List<TransportHealth>> transportHealths =
      ValueNotifier(const []);
  final List<VoidCallback> _healthListeners = [];
  List<MeshTransport> _activeTransports = const [];
```

En `start()`, tras crear el router y arrancarlo, guarda los transportes y
suscríbete (el router ya recibió la lista; guárdala también en el service —
cambia la línea que construye el router para capturar la lista primero):

```dart
      final transports =
          _transportsOverride ?? defaultTransports(deviceId: id.id);
      _activeTransports = transports;
      final router = MeshRouter(
        deviceId: id.id,
        transports: transports,
        channels: _channelsFromDisk(),
        store: store,
      );
```

y tras `await router.start();`:

```dart
      _wireHealth(router);
```

Métodos nuevos:

```dart
  void _wireHealth(MeshRouter router) {
    for (final t in _activeTransports) {
      if (t is HealthReporting) {
        void listener() => _publishHealth(router);
        (t as HealthReporting).health.addListener(listener);
        _healthListeners.add(listener);
      }
    }
    _publishHealth(router);
  }

  void _publishHealth(MeshRouter router) {
    transportHealths.value = [
      for (final t in _activeTransports)
        (t is HealthReporting
                ? (t as HealthReporting).health.value
                : TransportHealth(
                    name: t.name, state: TransportState.searching))
            .copyWith(peers: router.peersVia(t.name)),
    ];
  }
```

En `_onEvent` (que ya actualiza `peerCount` con cada evento — búscalo), añade
al final: `final r = _router; if (r != null) _publishHealth(r);` para que el
conteo de pares por transporte se refresque al oír tráfico. En `stop()`:
limpia listeners (`_healthListeners.clear()` tras remover cada uno de su
notifier correspondiente iterando `_activeTransports`), y
`transportHealths.value = const [];`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/mesh_service_health_test.dart test/mesh_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/modules/mesh/mesh_service.dart test/mesh_service_health_test.dart
git commit -m "feat(mesh): MeshService publica salud agregada de transportes"
```

## FASE 2 — Asistente de conexión

### Task 7: Motor de reglas ConnectionAdvisor

**Files:**
- Create: `lib/modules/mesh/connection_advisor.dart`
- Test: `test/connection_advisor_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/connection_advisor.dart';
import 'package:prepper_pad/modules/mesh/transport_health.dart';

TransportHealth _h(String name, TransportState s, {int peers = 0}) =>
    TransportHealth(name: name, state: s, peers: peers);

void main() {
  test('con pares conectados no hay pasos', () {
    final steps = ConnectionAdvisor.advise(
      healths: [_h('ble', TransportState.connected, peers: 2)],
      platform: TargetPlatform.android,
      searching: const Duration(seconds: 60),
    );
    expect(steps, isEmpty);
  });

  test('bluetooth apagado es el primer paso', () {
    final steps = ConnectionAdvisor.advise(
      healths: [
        _h('ble', TransportState.off),
        _h('lan', TransportState.searching),
      ],
      platform: TargetPlatform.iOS,
      searching: const Duration(seconds: 5),
    );
    expect(steps.first.kind, AdvisorStepKind.bluetoothOff);
  });

  test('permiso denegado sugiere ajustes de la app', () {
    final steps = ConnectionAdvisor.advise(
      healths: [_h('ble', TransportState.noPermission)],
      platform: TargetPlatform.iOS,
      searching: const Duration(seconds: 5),
    );
    expect(steps.first.kind, AdvisorStepKind.bluetoothPermission);
  });

  test('todo bien pero solo tras 30s propone hotspot', () {
    final early = ConnectionAdvisor.advise(
      healths: [
        _h('ble', TransportState.searching),
        _h('lan', TransportState.searching),
      ],
      platform: TargetPlatform.android,
      searching: const Duration(seconds: 10),
    );
    expect(early.any((s) => s.kind == AdvisorStepKind.hotspot), isFalse);

    final late = ConnectionAdvisor.advise(
      healths: [
        _h('ble', TransportState.searching),
        _h('lan', TransportState.searching),
      ],
      platform: TargetPlatform.android,
      searching: const Duration(seconds: 45),
    );
    expect(late.any((s) => s.kind == AdvisorStepKind.hotspot), isTrue);
    // LoRa siempre es el último recurso informativo tras 30s
    expect(late.last.kind, AdvisorStepKind.lora);
  });

  test('sin red LAN el hint acelera la sugerencia de hotspot', () {
    final steps = ConnectionAdvisor.advise(
      healths: [
        _h('ble', TransportState.searching),
        const TransportHealth(
            name: 'lan',
            state: TransportState.unavailable,
            hint: 'no_network'),
      ],
      platform: TargetPlatform.android,
      searching: const Duration(seconds: 5),
    );
    expect(steps.any((s) => s.kind == AdvisorStepKind.hotspot), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/connection_advisor_test.dart`
Expected: FAIL — archivo no existe

- [ ] **Step 3: Implement**

```dart
// Motor de reglas del Asistente de conexión. Puro (sin Flutter UI, sin
// side-effects): recibe la salud de los transportes y devuelve los pasos que
// el usuario debe seguir, ordenados por impacto. La UI solo los pinta.
import 'package:flutter/foundation.dart';

import 'transport_health.dart';

enum AdvisorStepKind {
  /// Bluetooth apagado: encenderlo reactiva el transporte de 0 config.
  bluetoothOff,

  /// Permiso Bluetooth denegado a la app.
  bluetoothPermission,

  /// Nadie a la vista y sin red común: crear un hotspot y unir a los demás.
  hotspot,

  /// Información: alcance de kilómetros con radio LoRa.
  lora,
}

@immutable
class AdvisorStep {
  const AdvisorStep(this.kind);
  final AdvisorStepKind kind;
}

class ConnectionAdvisor {
  /// Cuánto esperar antes de sugerir el hotspot cuando todo parece bien
  /// (los bursts de discovery del mesh tardan unos segundos en converger).
  static const Duration hotspotAfter = Duration(seconds: 30);

  static List<AdvisorStep> advise({
    required List<TransportHealth> healths,
    required TargetPlatform platform,
    required Duration searching,
  }) {
    final anyPeers = healths.any((h) => h.peers > 0);
    if (anyPeers) return const [];

    final steps = <AdvisorStep>[];
    TransportHealth? byName(String n) {
      for (final h in healths) {
        if (h.name == n) return h;
      }
      return null;
    }

    final ble = byName('ble');
    if (ble?.state == TransportState.off) {
      steps.add(const AdvisorStep(AdvisorStepKind.bluetoothOff));
    } else if (ble?.state == TransportState.noPermission) {
      steps.add(const AdvisorStep(AdvisorStepKind.bluetoothPermission));
    }

    final lan = byName('lan');
    final noNetwork = lan?.hint == 'no_network' ||
        lan?.state == TransportState.off;
    if (noNetwork || searching >= hotspotAfter) {
      steps.add(const AdvisorStep(AdvisorStepKind.hotspot));
    }

    if (searching >= hotspotAfter) {
      steps.add(const AdvisorStep(AdvisorStepKind.lora));
    }
    return steps;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/connection_advisor_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/modules/mesh/connection_advisor.dart test/connection_advisor_test.dart
git commit -m "feat(mesh): motor de reglas ConnectionAdvisor"
```

### Task 8: Textos i18n del asistente (7 idiomas)

**Files:**
- Modify: `lib/core/locale_service.dart` (mapa `AppStrings.allKeys`, ~línea 98)
- Test: la suite existente de i18n (`test/locale_service_test.dart` o similar — el test que valida `coreKeys`) sigue verde; agrega las claves nuevas a `coreKeys` porque el mesh es superficie vital.

- [ ] **Step 1: Agrega las claves al final del mapa `allKeys`**

```dart
    'meshBannerConnected': {
      'es': '{n} dispositivos conectados', 'en': '{n} devices connected',
      'pt': '{n} dispositivos conectados', 'fr': '{n} appareils connectés',
      'zh': '已连接 {n} 台设备', 'ja': '{n}台のデバイスが接続中',
      'ht': '{n} aparèy konekte',
    },
    'meshBannerSearching': {
      'es': 'Buscando dispositivos…', 'en': 'Searching for devices…',
      'pt': 'Procurando dispositivos…', 'fr': 'Recherche d’appareils…',
      'zh': '正在搜索设备…', 'ja': 'デバイスを検索中…', 'ht': 'K ap chèche aparèy…',
    },
    'meshBannerTapHelp': {
      'es': 'Toca para ver qué falta', 'en': 'Tap to see what’s missing',
      'pt': 'Toque para ver o que falta', 'fr': 'Touchez pour voir ce qui manque',
      'zh': '点按查看缺少什么', 'ja': 'タップして不足を確認', 'ht': 'Peze pou wè sa ki manke',
    },
    'advisorTitle': {
      'es': 'Asistente de conexión', 'en': 'Connection assistant',
      'pt': 'Assistente de conexão', 'fr': 'Assistant de connexion',
      'zh': '连接助手', 'ja': '接続アシスタント', 'ht': 'Asistan koneksyon',
    },
    'advisorBtOff': {
      'es': 'Enciende Bluetooth', 'en': 'Turn on Bluetooth',
      'pt': 'Ligue o Bluetooth', 'fr': 'Activez le Bluetooth',
      'zh': '打开蓝牙', 'ja': 'Bluetoothをオンにする', 'ht': 'Limen Bluetooth',
    },
    'advisorBtOffBody': {
      'es': 'Abre Ajustes → Bluetooth y actívalo. Los dispositivos cercanos se encontrarán solos, sin internet.',
      'en': 'Open Settings → Bluetooth and turn it on. Nearby devices will find each other automatically, no internet needed.',
      'pt': 'Abra Ajustes → Bluetooth e ative-o. Os dispositivos próximos se encontrarão sozinhos, sem internet.',
      'fr': 'Ouvrez Réglages → Bluetooth et activez-le. Les appareils proches se trouveront seuls, sans internet.',
      'zh': '打开 设置 → 蓝牙 并启用。附近的设备会自动互相发现，无需互联网。',
      'ja': '設定 → Bluetooth を開いてオンにしてください。近くのデバイスはインターネットなしで自動的に見つかります。',
      'ht': 'Ouvri Paramèt → Bluetooth epi limen li. Aparèy ki tou pre yo ap jwenn youn lòt poukont yo, san entènèt.',
    },
    'advisorBtPerm': {
      'es': 'Permite el acceso a Bluetooth', 'en': 'Allow Bluetooth access',
      'pt': 'Permita o acesso ao Bluetooth', 'fr': 'Autorisez l’accès Bluetooth',
      'zh': '允许蓝牙权限', 'ja': 'Bluetoothへのアクセスを許可', 'ht': 'Pèmèt aksè Bluetooth',
    },
    'advisorBtPermBody': {
      'es': 'La app no tiene permiso de Bluetooth. Abre Ajustes → Apps → Prepper Pad → Permisos y permite Bluetooth / Dispositivos cercanos.',
      'en': 'The app has no Bluetooth permission. Open Settings → Apps → Prepper Pad → Permissions and allow Bluetooth / Nearby devices.',
      'pt': 'O app não tem permissão de Bluetooth. Abra Ajustes → Apps → Prepper Pad → Permissões e permita Bluetooth / Dispositivos próximos.',
      'fr': 'L’app n’a pas la permission Bluetooth. Ouvrez Réglages → Apps → Prepper Pad → Autorisations et autorisez Bluetooth / Appareils à proximité.',
      'zh': '应用没有蓝牙权限。打开 设置 → 应用 → Prepper Pad → 权限，允许蓝牙/附近的设备。',
      'ja': 'アプリにBluetooth権限がありません。設定 → アプリ → Prepper Pad → 権限 で Bluetooth/付近のデバイス を許可してください。',
      'ht': 'App la pa gen pèmisyon Bluetooth. Ouvri Paramèt → App → Prepper Pad → Pèmisyon epi pèmèt Bluetooth / Aparèy tou pre.',
    },
    'advisorHotspot': {
      'es': 'Crea un punto de acceso (hotspot)', 'en': 'Create a hotspot',
      'pt': 'Crie um ponto de acesso (hotspot)', 'fr': 'Créez un point d’accès (hotspot)',
      'zh': '创建热点', 'ja': 'テザリング（ホットスポット）を作成', 'ht': 'Kreye yon hotspot',
    },
    'advisorHotspotBody': {
      'es': 'Sin router, un teléfono puede ser la red:\n\n1. En UN teléfono: Ajustes → Punto de acceso / Compartir internet → Actívalo (no importa que no haya internet).\n2. En LOS DEMÁS dispositivos: Ajustes → WiFi → únete a esa red.\n3. Vuelve aquí: se encontrarán solos en segundos.',
      'en': 'Without a router, one phone can be the network:\n\n1. On ONE phone: Settings → Hotspot / Tethering → turn it on (it doesn’t matter that there is no internet).\n2. On the OTHER devices: Settings → WiFi → join that network.\n3. Come back here: they will find each other in seconds.',
      'pt': 'Sem roteador, um telefone pode ser a rede:\n\n1. Em UM telefone: Ajustes → Ponto de acesso → ative-o (não importa que não haja internet).\n2. Nos OUTROS dispositivos: Ajustes → WiFi → entre nessa rede.\n3. Volte aqui: eles se encontrarão em segundos.',
      'fr': 'Sans routeur, un téléphone peut être le réseau :\n\n1. Sur UN téléphone : Réglages → Partage de connexion → activez-le (peu importe s’il n’y a pas d’internet).\n2. Sur les AUTRES appareils : Réglages → WiFi → rejoignez ce réseau.\n3. Revenez ici : ils se trouveront en quelques secondes.',
      'zh': '没有路由器时，一部手机就是网络：\n\n1. 在一部手机上：设置 → 个人热点 → 开启（没有互联网也没关系）。\n2. 在其他设备上：设置 → WiFi → 加入该网络。\n3. 回到这里：几秒钟内它们就会互相发现。',
      'ja': 'ルーターがなくても、1台のスマホがネットワークになれます：\n\n1. 1台のスマホで：設定 → テザリング → オンにする（インターネットがなくてもOK）。\n2. 他のデバイスで：設定 → WiFi → そのネットワークに接続。\n3. ここに戻る：数秒でお互いを見つけます。',
      'ht': 'San routeur, yon telefòn ka sèvi kòm rezo a:\n\n1. Sou YON telefòn: Paramèt → Hotspot → limen li (pa gen pwoblèm si pa gen entènèt).\n2. Sou LÒT aparèy yo: Paramèt → WiFi → antre nan rezo sa a.\n3. Tounen isit la: y ap jwenn youn lòt nan kèk segond.',
    },
    'advisorLora': {
      'es': '¿Necesitas kilómetros de alcance?', 'en': 'Need kilometers of range?',
      'pt': 'Precisa de quilômetros de alcance?', 'fr': 'Besoin de kilomètres de portée ?',
      'zh': '需要数公里的通信距离？', 'ja': '数kmの通信距離が必要？', 'ht': 'Bezwen plizyè kilomèt distans?',
    },
    'advisorLoraBody': {
      'es': 'Con una radio LoRa (módulo Nordic UART por Bluetooth) el mesh alcanza kilómetros sin ninguna red. Conecta la radio y activa LoRa en Comunicación → ajustes.',
      'en': 'With a LoRa radio (Nordic UART module over Bluetooth) the mesh reaches kilometers with no network at all. Connect the radio and enable LoRa in Communication → settings.',
      'pt': 'Com um rádio LoRa (módulo Nordic UART por Bluetooth) o mesh alcança quilômetros sem nenhuma rede. Conecte o rádio e ative LoRa em Comunicação → ajustes.',
      'fr': 'Avec une radio LoRa (module Nordic UART en Bluetooth), le mesh atteint des kilomètres sans aucun réseau. Connectez la radio et activez LoRa dans Communication → réglages.',
      'zh': '使用LoRa电台（通过蓝牙的Nordic UART模块），无需任何网络即可达到数公里。连接电台并在 通信 → 设置 中启用LoRa。',
      'ja': 'LoRa無線（Bluetooth経由のNordic UARTモジュール）でネットワークなしで数km届きます。無線を接続し、通信 → 設定 でLoRaを有効にしてください。',
      'ht': 'Avèk yon radyo LoRa (modil Nordic UART sou Bluetooth) mesh la rive plizyè kilomèt san okenn rezo. Konekte radyo a epi aktive LoRa nan Kominikasyon → paramèt.',
    },
```

- [ ] **Step 2: Agrega las claves nuevas a `coreKeys`** (lista ~línea 88; el
mesh es superficie vital): `'meshBannerConnected', 'meshBannerSearching',
'meshBannerTapHelp', 'advisorTitle', 'advisorBtOff', 'advisorBtOffBody',
'advisorBtPerm', 'advisorBtPermBody', 'advisorHotspot', 'advisorHotspotBody',
'advisorLora', 'advisorLoraBody',`

- [ ] **Step 3: Run i18n tests**

Run: `flutter test test/ --plain-name locale; flutter test test/ --plain-name i18n`
Expected: PASS (el test de coreKeys valida los 7 idiomas de cada clave nueva)

- [ ] **Step 4: Commit**

```bash
git add lib/core/locale_service.dart
git commit -m "feat(i18n): textos del asistente de conexión en 7 idiomas"
```

### Task 9: Banner + hoja del asistente en Comunicación

**Files:**
- Create: `lib/modules/mesh/connection_banner.dart`
- Modify: `lib/modules/mesh/mesh_page.dart` (insertar banner en la vista principal)
- Test: `test/connection_banner_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/connection_banner.dart';
import 'package:prepper_pad/modules/mesh/transport_health.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('con pares muestra estado verde con el conteo', (tester) async {
    await tester.pumpWidget(_wrap(ConnectionBanner(
      healths: const [
        TransportHealth(
            name: 'ble', state: TransportState.connected, peers: 2),
        TransportHealth(
            name: 'lan', state: TransportState.connected, peers: 1),
      ],
      searching: Duration.zero,
    )));
    // 2 pares únicos como máximo por transporte → el banner muestra el total
    // agregado (max por par no es posible sin ids; se muestra la suma).
    expect(find.textContaining('3'), findsOneWidget);
  });

  testWidgets('sin pares muestra búsqueda y abre el asistente al tocar',
      (tester) async {
    await tester.pumpWidget(_wrap(ConnectionBanner(
      healths: const [
        TransportHealth(name: 'ble', state: TransportState.off),
      ],
      searching: Duration(seconds: 60),
    )));
    expect(find.textContaining('Buscando'), findsOneWidget);
    await tester.tap(find.byType(ConnectionBanner));
    await tester.pumpAndSettle();
    // La hoja del asistente lista el paso de Bluetooth apagado.
    expect(find.textContaining('Bluetooth'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/connection_banner_test.dart`
Expected: FAIL — archivo no existe

- [ ] **Step 3: Implement `connection_banner.dart`**

```dart
// Banner de estado del mesh + hoja del Asistente de conexión.
// Siempre visible en Comunicación: verde cuando hay pares (y por qué
// transporte), ámbar cuando busca — tocar abre pasos grandes, uno por
// tarjeta, pensados para leerse en pánico.
import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import 'connection_advisor.dart';
import 'transport_health.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.healths,
    required this.searching,
  });

  final List<TransportHealth> healths;
  final Duration searching;

  int get _peerTotal => healths.fold(0, (a, h) => a + h.peers);

  static const _transportLabels = {
    'ble': 'Bluetooth',
    'lan': 'WiFi',
    'wifi_direct': 'WiFi Direct',
    'lora': 'LoRa',
  };

  String _viaLabel() {
    final active = [
      for (final h in healths)
        if (h.peers > 0) _transportLabels[h.name] ?? h.name,
    ];
    return active.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final connected = _peerTotal > 0;
    final color = connected ? Colors.green : Colors.orange;
    final title = connected
        ? '${tr(context, 'meshBannerConnected').replaceFirst('{n}', '$_peerTotal')} · ${_viaLabel()}'
        : tr(context, 'meshBannerSearching');
    return Material(
      color: color.withValues(alpha: 0.15),
      child: InkWell(
        onTap: connected ? null : () => _openAssistant(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(connected ? Icons.check_circle : Icons.wifi_find,
                  color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (!connected)
                      Text(tr(context, 'meshBannerTapHelp'),
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (!connected) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _openAssistant(BuildContext context) {
    final steps = ConnectionAdvisor.advise(
      healths: healths,
      platform: Theme.of(context).platform,
      searching: searching,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AssistantSheet(steps: steps),
    );
  }
}

class _AssistantSheet extends StatelessWidget {
  const _AssistantSheet({required this.steps});
  final List<AdvisorStep> steps;

  (String, String) _texts(BuildContext c, AdvisorStepKind kind) =>
      switch (kind) {
        AdvisorStepKind.bluetoothOff =>
          (tr(c, 'advisorBtOff'), tr(c, 'advisorBtOffBody')),
        AdvisorStepKind.bluetoothPermission =>
          (tr(c, 'advisorBtPerm'), tr(c, 'advisorBtPermBody')),
        AdvisorStepKind.hotspot =>
          (tr(c, 'advisorHotspot'), tr(c, 'advisorHotspotBody')),
        AdvisorStepKind.lora =>
          (tr(c, 'advisorLora'), tr(c, 'advisorLoraBody')),
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(context, 'advisorTitle'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (steps.isEmpty)
              Text(tr(context, 'meshBannerSearching')),
            for (final (i, step) in steps.indexed) ...[
              Builder(builder: (c) {
                final (title, body) = _texts(c, step.kind);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. $title',
                            style: Theme.of(c)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(body,
                            style: Theme.of(c).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
```

Nota: si `tr(context, …)` no existe como función global, revisa cómo lo
importa `mesh_page.dart` (línea ~10, `../../core/locale_service.dart`) y usa
exactamente el mismo mecanismo.

- [ ] **Step 4: Run to verify banner tests pass**

Run: `flutter test test/connection_banner_test.dart`
Expected: PASS (2 tests). El test usa strings ES por defecto — si el helper
`tr` resuelve otro idioma por defecto en tests, ajusta expectativas al idioma
por defecto real (`AppLanguage.es` según locale_service).

- [ ] **Step 5: Integrar en mesh_page**

En `mesh_page.dart`: import `connection_banner.dart` y `transport_health.dart`.
En `_MeshPageState` agrega un timestamp de inicio de búsqueda:

```dart
  final _searchStart = DateTime.now();
```

Localiza el `build` de la vista principal (la rama cuando `hasIdentity` es
true — busca dónde se construye la lista de canales). Envuelve el contenido
para que el banner quede arriba, observando la salud:

```dart
    return ValueListenableBuilder<List<TransportHealth>>(
      valueListenable: _service.transportHealths,
      builder: (context, healths, _) => Column(
        children: [
          ConnectionBanner(
            healths: healths,
            searching: DateTime.now().difference(_searchStart),
          ),
          Expanded(child: /* contenido existente de la vista principal */),
        ],
      ),
    );
```

- [ ] **Step 6: Run full suite + analyze**

Run: `flutter analyze lib/ && flutter test`
Expected: `No issues found!` y toda la suite PASS

- [ ] **Step 7: Commit**

```bash
git add lib/modules/mesh/connection_banner.dart lib/modules/mesh/mesh_page.dart test/connection_banner_test.dart
git commit -m "feat(mesh): banner de estado + asistente de conexión en Comunicación"
```

## FASE 3 — BLE nativo para Windows

### Task 10: Dart habilita Windows en el link nativo

**Files:**
- Modify: `lib/modules/mesh/ble_transport.dart` (`NativeBleMeshLink.adapterAvailable` ~línea 370 y selección de link en `BleTransport` ~línea 468)

- [ ] **Step 1: Agrega Windows a ambos sitios**

En `NativeBleMeshLink.adapterAvailable` y en el constructor de `BleTransport`
(la condición que elige `NativeBleMeshLink()` vs `FlutterBluePlusLink()`),
agrega `|| defaultTargetPlatform == TargetPlatform.windows` a la lista de
plataformas con bridge nativo.

- [ ] **Step 2: Run tests**

Run: `flutter test test/ble_transport_test.dart`
Expected: PASS (los tests usan links falsos; no dependen de plataforma)

- [ ] **Step 3: Commit**

```bash
git add lib/modules/mesh/ble_transport.dart
git commit -m "feat(mesh): Dart selecciona bridge BLE nativo también en Windows"
```

### Task 11: Bridge WinRT (advertise + scan, mismo protocolo)

**Files:**
- Create: `windows/runner/ble_mesh_bridge.h`
- Create: `windows/runner/ble_mesh_bridge.cpp`
- Modify: `windows/runner/flutter_window.cpp` (registro tras `RegisterPlugins`, línea 27)
- Modify: `windows/runner/CMakeLists.txt` (agregar el .cpp a la lista de fuentes y linkear `windowsapp`)

El bridge replica `BleMeshBridge.kt`: MethodChannel `prepper/ble_mesh`
(start/stop/connect/disconnect/send), EventChannel `prepper/ble_mesh/events`
(eventos `{type: peer|data|state, id, bytes}`), servicio GATT
`0000ffe0-…` con write-char `ffe1` (los pares nos escriben) y notify-char
`ffe2` (nosotros notificamos a los pares).

- [ ] **Step 1: `ble_mesh_bridge.h`**

```cpp
#ifndef RUNNER_BLE_MESH_BRIDGE_H_
#define RUNNER_BLE_MESH_BRIDGE_H_

#include <flutter/binary_messenger.h>

// Registers the prepper/ble_mesh method+event channels backed by WinRT BLE
// (GattServiceProvider for the peripheral role, BluetoothLEAdvertisement-
// Watcher + GattSession for the central role). Mirrors BleMeshBridge.kt.
void RegisterBleMeshBridge(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_BLE_MESH_BRIDGE_H_
```

- [ ] **Step 2: `ble_mesh_bridge.cpp`** — implementación completa:

```cpp
#include "ble_mesh_bridge.h"

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.Streams.h>

#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

using namespace winrt;
using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Bluetooth::Advertisement;
using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
using namespace winrt::Windows::Storage::Streams;

namespace {

const guid kServiceUuid{0x0000ffe0, 0x0000, 0x1000,
                        {0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb}};
const guid kTxUuid{0x0000ffe1, 0x0000, 0x1000,
                   {0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb}};
const guid kRxUuid{0x0000ffe2, 0x0000, 0x1000,
                   {0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb}};

std::string AddressToId(uint64_t addr) {
  std::ostringstream o;
  o << std::hex << addr;
  return o.str();
}

IBuffer ToBuffer(const std::vector<uint8_t>& bytes) {
  DataWriter w;
  w.WriteBytes(array_view<const uint8_t>(bytes.data(),
                                         bytes.data() + bytes.size()));
  return w.DetachBuffer();
}

std::vector<uint8_t> FromBuffer(const IBuffer& buf) {
  DataReader r = DataReader::FromBuffer(buf);
  std::vector<uint8_t> out(buf.Length());
  r.ReadBytes(array_view<uint8_t>(out.data(), out.data() + out.size()));
  return out;
}

// One connected remote peer we act as CENTRAL for.
struct Peer {
  BluetoothLEDevice device{nullptr};
  GattCharacteristic tx{nullptr};   // we write mesh chunks here
  GattCharacteristic rx{nullptr};   // peer notifies us here
  winrt::event_token rx_token{};
};

class BleMeshBridge {
 public:
  explicit BleMeshBridge(flutter::BinaryMessenger* messenger) {
    method_channel_ =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "prepper/ble_mesh",
            &flutter::StandardMethodCodec::GetInstance());
    event_channel_ =
        std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
            messenger, "prepper/ble_mesh/events",
            &flutter::StandardMethodCodec::GetInstance());

    event_channel_->SetStreamHandler(
        std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
            [this](auto, auto&& events) {
              std::lock_guard<std::mutex> lock(mutex_);
              sink_ = std::move(events);
              return nullptr;
            },
            [this](auto) {
              std::lock_guard<std::mutex> lock(mutex_);
              sink_.reset();
              return nullptr;
            }));

    method_channel_->SetMethodCallHandler([this](const auto& call,
                                                 auto result) {
      const std::string& m = call.method_name();
      if (m == "start") {
        result->Success(flutter::EncodableValue(Start()));
      } else if (m == "stop") {
        Stop();
        result->Success(flutter::EncodableValue(true));
      } else if (m == "connect") {
        result->Success(flutter::EncodableValue(Connect(ArgId(call))));
      } else if (m == "disconnect") {
        Disconnect(ArgId(call));
        result->Success(flutter::EncodableValue(true));
      } else if (m == "send") {
        result->Success(
            flutter::EncodableValue(Send(ArgId(call), ArgBytes(call))));
      } else {
        result->NotImplemented();
      }
    });
  }

 private:
  static std::string ArgId(
      const flutter::MethodCall<flutter::EncodableValue>& call) {
    if (const auto* map =
            std::get_if<flutter::EncodableMap>(call.arguments())) {
      auto it = map->find(flutter::EncodableValue("id"));
      if (it != map->end()) {
        if (const auto* s = std::get_if<std::string>(&it->second)) return *s;
      }
    }
    return "";
  }

  static std::vector<uint8_t> ArgBytes(
      const flutter::MethodCall<flutter::EncodableValue>& call) {
    if (const auto* map =
            std::get_if<flutter::EncodableMap>(call.arguments())) {
      auto it = map->find(flutter::EncodableValue("bytes"));
      if (it != map->end()) {
        if (const auto* v = std::get_if<std::vector<uint8_t>>(&it->second))
          return *v;
      }
    }
    return {};
  }

  void Emit(flutter::EncodableMap event) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (sink_) sink_->Success(flutter::EncodableValue(std::move(event)));
  }

  void EmitState(const char* value) {
    Emit({{flutter::EncodableValue("type"), flutter::EncodableValue("state")},
          {flutter::EncodableValue("value"), flutter::EncodableValue(value)}});
  }

  bool Start() {
    try {
      StartPeripheral();
      StartWatcher();
      EmitState("on");
      return true;
    } catch (const hresult_error&) {
      EmitState("unsupported");
      return false;
    }
  }

  // PERIPHERAL: publish the ffe0 service (write char ffe1, notify char ffe2)
  // and advertise it so phones discover this PC exactly like an Android.
  void StartPeripheral() {
    auto op = GattServiceProvider::CreateAsync(kServiceUuid).get();
    if (op.Error() != BluetoothError::Success) {
      throw hresult_error(E_FAIL);
    }
    provider_ = op.ServiceProvider();

    GattLocalCharacteristicParameters writeParams;
    writeParams.CharacteristicProperties(
        GattCharacteristicProperties::Write |
        GattCharacteristicProperties::WriteWithoutResponse);
    auto writeChar = provider_.Service()
                         .CreateCharacteristicAsync(kTxUuid, writeParams)
                         .get()
                         .Characteristic();
    writeChar.WriteRequested([this](GattLocalCharacteristic const&,
                                    GattWriteRequestedEventArgs const& args) {
      auto deferral = args.GetDeferral();
      auto request = args.GetRequestAsync().get();
      auto bytes = FromBuffer(request.Value());
      auto session = args.Session();
      std::string id =
          AddressToId(session.DeviceId().Id().size());  // session-scoped id
      Emit({{flutter::EncodableValue("type"), flutter::EncodableValue("data")},
            {flutter::EncodableValue("id"),
             flutter::EncodableValue(winrt::to_string(
                 session.DeviceId().Id()))},
            {flutter::EncodableValue("bytes"),
             flutter::EncodableValue(bytes)}});
      if (request.Option() == GattWriteOption::WriteWithResponse) {
        request.Respond();
      }
      deferral.Complete();
    });

    GattLocalCharacteristicParameters notifyParams;
    notifyParams.CharacteristicProperties(
        GattCharacteristicProperties::Notify);
    notify_char_ = provider_.Service()
                       .CreateCharacteristicAsync(kRxUuid, notifyParams)
                       .get()
                       .Characteristic();

    GattServiceProviderAdvertisingParameters adv;
    adv.IsConnectable(true);
    adv.IsDiscoverable(true);
    provider_.StartAdvertising(adv);
  }

  // CENTRAL: watch for peers advertising ffe0 and report them to Dart.
  void StartWatcher() {
    watcher_ = BluetoothLEAdvertisementWatcher();
    watcher_.ScanningMode(BluetoothLEScanningMode::Active);
    watcher_.Received([this](BluetoothLEAdvertisementWatcher const&,
                             BluetoothLEAdvertisementReceivedEventArgs const&
                                 args) {
      for (auto const& uuid : args.Advertisement().ServiceUuids()) {
        if (uuid == kServiceUuid) {
          Emit({{flutter::EncodableValue("type"),
                 flutter::EncodableValue("peer")},
                {flutter::EncodableValue("id"),
                 flutter::EncodableValue(
                     AddressToId(args.BluetoothAddress()))}});
          break;
        }
      }
    });
    watcher_.Start();
  }

  bool Connect(const std::string& id) {
    if (id.empty()) return false;
    try {
      uint64_t addr = std::stoull(id, nullptr, 16);
      auto device = BluetoothLEDevice::FromBluetoothAddressAsync(addr).get();
      if (!device) return false;
      auto services =
          device.GetGattServicesForUuidAsync(kServiceUuid).get().Services();
      if (services.Size() == 0) return false;
      auto service = services.GetAt(0);
      Peer peer;
      peer.device = device;
      for (auto const& c :
           service.GetCharacteristicsForUuidAsync(kTxUuid).get()
               .Characteristics()) {
        peer.tx = c;
      }
      for (auto const& c :
           service.GetCharacteristicsForUuidAsync(kRxUuid).get()
               .Characteristics()) {
        peer.rx = c;
      }
      if (!peer.tx || !peer.rx) return false;
      peer.rx.WriteClientCharacteristicConfigurationDescriptorAsync(
              GattClientCharacteristicConfigurationDescriptorValue::Notify)
          .get();
      peer.rx_token = peer.rx.ValueChanged(
          [this, id](GattCharacteristic const&,
                     GattValueChangedEventArgs const& args) {
            Emit({{flutter::EncodableValue("type"),
                   flutter::EncodableValue("data")},
                  {flutter::EncodableValue("id"),
                   flutter::EncodableValue(id)},
                  {flutter::EncodableValue("bytes"),
                   flutter::EncodableValue(FromBuffer(args.CharacteristicValue()))}});
          });
      std::lock_guard<std::mutex> lock(mutex_);
      peers_[id] = std::move(peer);
      return true;
    } catch (const hresult_error&) {
      return false;
    } catch (const std::exception&) {
      return false;
    }
  }

  void Disconnect(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = peers_.find(id);
    if (it == peers_.end()) return;
    if (it->second.rx && it->second.rx_token) {
      it->second.rx.ValueChanged(it->second.rx_token);
    }
    if (it->second.device) it->second.device.Close();
    peers_.erase(it);
  }

  bool Send(const std::string& id, const std::vector<uint8_t>& bytes) {
    if (id.empty() || bytes.empty()) return false;
    GattCharacteristic tx{nullptr};
    {
      std::lock_guard<std::mutex> lock(mutex_);
      auto it = peers_.find(id);
      if (it != peers_.end()) tx = it->second.tx;
    }
    try {
      if (tx) {
        tx.WriteValueAsync(ToBuffer(bytes),
                           GattWriteOption::WriteWithoutResponse)
            .get();
        return true;
      }
      // No central link: the peer may be connected to US as a central —
      // notify every subscribed client (mirror of the kt server path).
      if (notify_char_) {
        notify_char_.NotifyValueAsync(ToBuffer(bytes)).get();
        return true;
      }
      return false;
    } catch (const hresult_error&) {
      return false;
    }
  }

  void Stop() {
    try {
      if (watcher_) watcher_.Stop();
      if (provider_) provider_.StopAdvertising();
    } catch (const hresult_error&) {
    }
    std::lock_guard<std::mutex> lock(mutex_);
    for (auto& [id, p] : peers_) {
      if (p.device) p.device.Close();
    }
    peers_.clear();
  }

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::mutex mutex_;

  GattServiceProvider provider_{nullptr};
  GattLocalCharacteristic notify_char_{nullptr};
  BluetoothLEAdvertisementWatcher watcher_{nullptr};
  std::map<std::string, Peer> peers_;
};

BleMeshBridge* g_bridge = nullptr;

}  // namespace

void RegisterBleMeshBridge(flutter::BinaryMessenger* messenger) {
  if (!g_bridge) g_bridge = new BleMeshBridge(messenger);
}
```

Nota de implementación: los `.get()` bloquean el hilo de plataforma durante
milisegundos (aceptable para conexiones BLE esporádicas; es el mismo patrón
síncrono del bridge Kotlin con colas). El id que emite `WriteRequested` es el
DeviceId de la sesión GATT (string), distinto del address hex del watcher —
consistente para el reensamblado porque cada dirección de flujo usa siempre el
mismo id, igual que en Android donde el server usa `device.address`.

- [ ] **Step 3: Registrar en `flutter_window.cpp`**

Tras la línea 27 (`RegisterPlugins(flutter_controller_->engine());`):

```cpp
  RegisterBleMeshBridge(flutter_controller_->engine()->messenger());
```

e incluye el header arriba: `#include "ble_mesh_bridge.h"`

- [ ] **Step 4: `CMakeLists.txt` del runner** — agrega `ble_mesh_bridge.cpp` a
`add_executable(${BINARY_NAME} WIN32 …)` y al final del target:

```cmake
target_link_libraries(${BINARY_NAME} PRIVATE windowsapp)
```

- [ ] **Step 5: Verificación (requiere PC Windows)**

En la PC Windows con Flutter instalado:
Run: `flutter build windows --debug 2>&1 | tail -3`
Expected: `√ Built build\windows\x64\runner\Debug\prepper_pad.exe`

Si no hay acceso a la PC ahora: commit igualmente (el código Windows no se
compila desde macOS; CI o la PC lo validará) y deja anotado en el commit.

- [ ] **Step 6: Commit**

```bash
git add windows/runner/ble_mesh_bridge.h windows/runner/ble_mesh_bridge.cpp windows/runner/flutter_window.cpp windows/runner/CMakeLists.txt
git commit -m "feat(mesh): bridge BLE WinRT — Windows entra al mesh sin red"
```

### Task 12: Verificación final y prueba real

- [ ] **Step 1: Suite completa + analyze**

Run: `flutter analyze lib/ && flutter test`
Expected: `No issues found!`, todos los tests PASS (≥ 280 tests con los nuevos)

- [ ] **Step 2: Prueba manual multi-dispositivo (checklist)**

1. Mac + iPhone con WiFi APAGADO en ambos → abrir Comunicación → en <30 s el
   banner muestra "1 dispositivos conectados · Bluetooth" en cada uno.
2. Apagar Bluetooth del iPhone → el banner pasa a ámbar y el asistente muestra
   "Enciende Bluetooth" como paso 1.
3. Android + iPhone sin red común → esperar 30 s → el asistente propone el
   hotspot; crearlo en el Android, unir el iPhone → banner verde vía WiFi.
4. (Con la PC Windows) `flutter run -d windows` → la PC aparece en el mesh de
   los teléfonos vía Bluetooth con WiFi desconectado.

- [ ] **Step 3: Commit final si hubo ajustes**

```bash
git add -A && git commit -m "test(mesh): verificación multi-dispositivo del descubrimiento universal"
```

---

## Self-review (hecho al escribir el plan)

- **Cobertura de spec:** Fase 1 → Tasks 1-6; Fase 2 → Tasks 7-9; Fase 3 →
  Tasks 10-11; criterios de éxito → Task 12. Hotspot manual guiado ✓, estados
  accionables ✓, 7 idiomas ✓, protocolo intacto ✓.
- **Placeholders:** ninguno — cada step tiene código o comando concreto. Los
  dos puntos que dependen de código existente no visible en el plan (factory
  exacta de MeshEnvelope para beacons; mecanismo exacto de `tr`) instruyen
  copiar el patrón de archivos concretos ya citados.
- **Consistencia de tipos:** `TransportHealth/TransportState/HealthReporting`
  (Task 1) usados idénticos en Tasks 3, 5, 6, 7, 9; `AdvisorStepKind` (Task 7)
  usado en Task 9; eventos `{type:'state', value}` (Task 3) emitidos igual en
  Tasks 4 y 11.
