# Descubrimiento universal inteligente entre dispositivos Prepper Pad

**Fecha:** 2026-07-09
**Estado:** Aprobado (Opción A, prioridad Android/Apple)

## Objetivo

Que cualquier par de dispositivos con Prepper Pad (Android, iPhone, Mac,
Windows) se encuentren solos, sin internet ni router, y que cuando no se
encuentren la app diagnostique por qué y guíe al usuario con pasos concretos.
Todo alimenta el mesh existente (chat, SOS, posición); el protocolo mesh y su
crypto no se tocan.

## Prioridad de implementación

1. **Fase 1 — Diagnóstico por transporte** (Android/iOS/macOS de inmediato).
2. **Fase 2 — Asistente de conexión** (UI + motor de reglas, todas las
   plataformas).
3. **Fase 3 — BLE nativo para Windows** (bridge WinRT; el usuario tiene una
   PC Windows para la prueba real).

## Arquitectura — la escalera de transportes

Se conserva `MeshTransport` (lib/modules/mesh/mesh_transport.dart) y el
`MeshRouter` tal cual. La escalera:

| Alcance | Transporte | Estado |
|---|---|---|
| Cerca (0-30 m) | BLE nativo (`prepper/ble_mesh`) | Android ✓ iOS ✓ macOS ✓ · **Windows NUEVO (Fase 3)** |
| Misma red | LAN UDP + Bonjour (`_prepperpad._udp`) | Todas ✓ (ya funciona) |
| Media (30-200 m) | WiFi Direct | Android ✓ (ya funciona) |
| Media sin red | Hotspot manual | **Guiado por el Asistente (Fase 2)** |
| Lejos (km) | LoRa BLE-UART | Opt-in existente; requiere radios físicas |

Piezas nuevas transversales: diagnóstico por transporte (Fase 1) y Asistente
de conexión (Fase 2).

## Fase 1 — Diagnóstico por transporte

Hoy los transportes degradan en silencio (patrón deliberado: nunca tiran el
mesh). Se agrega visibilidad sin cambiar ese patrón:

```dart
enum TransportState { off, unavailable, noPermission, searching, connected }

class TransportHealth {
  final String name;         // 'ble', 'lan', 'wifi_direct', 'lora'
  final TransportState state;
  final int peers;           // pares vivos vía este transporte
  final String? hint;        // ej. 'bluetooth_off', 'no_network', 'no_adapter'
}
```

- Cada transporte expone `ValueNotifier<TransportHealth> health`.
- Los bridges nativos ya conocen el estado del adaptador
  (`CBCentralManager.state` en Swift, `BluetoothAdapter` en Kotlin); lo
  emiten por el EventChannel existente como evento nuevo
  `{type: 'state', value: <string>}`. El link Dart lo traduce a
  `TransportState`.
- El transporte LAN deriva su estado de `connectivity_plus` (ya es
  dependencia) + si el socket UDP abrió.
- `MeshService` agrega los health en una lista observable
  (`ValueNotifier<List<TransportHealth>>`) para la UI y el asistente.
- El conteo de pares por transporte sale del router: ya sabe por cuál
  transporte llegó cada datagrama.

## Fase 2 — Asistente de conexión

**Motor de reglas puro** (`lib/modules/mesh/connection_advisor.dart`, sin
dependencias de Flutter UI, unit-testeable): recibe
`List<TransportHealth>` + `TargetPlatform` + tiempo buscando sin éxito, y
devuelve pasos ordenados por impacto:

1. Bluetooth apagado → "Enciende Bluetooth" (botón a ajustes del sistema).
2. Permiso denegado (BT / red local iOS) → "Permite el acceso" (abre ajustes
   de permisos de la app).
3. Todo encendido, 0 pares tras ~30 s → guía de hotspot por plataforma:
   "Crea un hotspot en un teléfono y conecta los demás a esa red" con los
   pasos exactos de iOS y Android. El transporte LAN hace el resto solo.
4. ¿Necesitas kilómetros? → explica LoRa y cómo activarla (toggle existente).

**UI** en `mesh_page.dart`:

- Banner de estado siempre visible: "🟢 3 dispositivos conectados por
  Bluetooth y WiFi" / "🟠 Buscando… toca para ver qué falta".
- Tocar abre el asistente: un paso grande a la vez, letras grandes, una
  acción por pantalla — pensado para pánico.
- Los textos siguen el sistema i18n existente (es/en).

## Fase 3 — BLE nativo para Windows

Bridge C++/WinRT en `windows/runner/ble_mesh_bridge.{h,cpp}` que replica
exactamente el protocolo de `BleMeshBridge.kt`/`.swift`:

- Mismos canales: MethodChannel `prepper/ble_mesh`
  (start/stop/connect/disconnect/send) y EventChannel
  `prepper/ble_mesh/events` (eventos `{type: peer|data|state, id, bytes}`).
- Mismo servicio GATT `0000ffe0-0000-1000-8000-00805f9b34fb` con TX `ffe1` /
  RX `ffe2` (constantes en `BleUuids`, ble_transport.dart).
- Doble rol: `GattServiceProvider` (advertising + servidor GATT, Windows 10
  1703+) y `BluetoothLEAdvertisementWatcher` (escaneo + cliente), para que
  Windows↔Windows también se vean.
- En Dart: `NativeBleMeshLink.adapterAvailable` agrega
  `TargetPlatform.windows`.
- PC sin adaptador BLE → `unavailable` con hint "esta PC no tiene Bluetooth
  LE; conéctala al WiFi/hotspot".

## Manejo de errores y degradación

- Ningún transporte puede tirar el mesh: se mantiene el patrón de degradar a
  no-op, ahora reportando su estado en vez de callar.
- El asistente es informativo, nunca bloquea; el mesh sigue reintentando en
  fondo (burst de discovery existente).
- Fragmentación BLE sin cambios: `BleFrame`/`BleReassembler` son agnósticos
  del link.

## Testing

- **Motor de reglas**: unit tests puros — matriz (estado × plataforma) →
  pasos esperados.
- **TransportHealth**: tests con links falsos (patrón `forTest` de
  `MeshService`), verificando que cada estado del adaptador produce el
  health correcto.
- **Windows bridge**: el framing ya está cubierto por
  `test/ble_transport_test.dart`; prueba real Windows↔iPhone/Android manual.
- **Regresión**: la suite completa (269 tests) sigue verde.

## Fuera de alcance (YAGNI)

- Hardware LoRa (no hay radios aún; el soporte opt-in ya existe).
- Hotspot automático programático (LocalOnlyHotspot de Android genera una
  red que iOS no puede unir sin QR; la guía manual es más universal).
- Cambios al protocolo mesh, envelopes o crypto.
- Linux (sin dispositivo real que probar; el fallback
  `FlutterBluePlusLink` queda como está).

## Criterio de éxito

1. iPhone, Android, Mac se ven entre sí **sin router** (BLE) y el banner
   dice por cuál transporte.
2. Con Bluetooth apagado, el asistente lo detecta y lleva a ajustes en ≤2
   toques.
3. Sin ningún par a la vista, el asistente propone el hotspot con pasos por
   plataforma; al crearlo, los dispositivos se ven por LAN sin tocar nada.
4. (Fase 3) La PC Windows aparece en el mesh vía BLE junto a los demás.
