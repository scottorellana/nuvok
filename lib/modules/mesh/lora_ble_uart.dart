// LoRa over BLE-UART: the production driver that plugs a real long-range
// radio into Prepper Mesh. Consumer LoRa adapters (Meshtastic T-Beam/Heltec,
// RAK, generic nRF52 boards) expose the Nordic UART Service (NUS) over BLE —
// a TX characteristic you write to and an RX characteristic that notifies.
// This driver scans for such a module, connects, and hands raw LoRa frames
// to/from the existing [LoraTransport] framing layer.
//
// The BLE plumbing sits behind [BleUartPort] so the whole driver is unit-
// tested with a fake port (no radio needed); [FlutterBlueUartPort] is the
// real implementation. Until a module is present the driver reports
// unavailable and LAN/BLE-mesh keep carrying traffic.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'lora_transport.dart';

/// Nordic UART Service UUIDs — the de-facto standard for "serial over BLE"
/// that virtually every hobby LoRa board exposes.
class NusUuids {
  static final service = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final tx = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e'); // write
  static final rx = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e'); // notify
}

/// Thin BLE-UART port seam: connect to a NUS device, write bytes, receive
/// notified bytes. Faked in tests; [FlutterBlueUartPort] is production.
abstract class BleUartPort {
  bool get isConnected;
  Stream<Uint8List> get incoming;
  Future<bool> connect();
  Future<void> disconnect();
  Future<bool> write(Uint8List data);
}

/// [LoraLinkDriver] backed by a BLE-UART port. Frames (≤230B, already sized
/// by [LoraFrame]) map 1:1 to BLE writes/notifications — no extra
/// fragmentation needed.
class BleUartLoraDriver implements LoraLinkDriver {
  BleUartLoraDriver({BleUartPort? port})
      : _port = port ?? FlutterBlueUartPort();

  final BleUartPort _port;

  @override
  bool get available => _port.isConnected;

  @override
  Future<bool> open() => _port.connect();

  @override
  Future<void> close() => _port.disconnect();

  @override
  Future<bool> writeFrame(Uint8List frame) => _port.write(frame);

  @override
  Stream<Uint8List> get onFrame => _port.incoming;
}

/// Real NUS-over-BLE port using flutter_blue_plus. Scans for a device
/// advertising the Nordic UART Service, connects, subscribes to RX and
/// exposes TX writes. Degrades to "not connected" on any failure so the mesh
/// never crashes for a missing/Сflaky radio.
class FlutterBlueUartPort implements BleUartPort {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _tx;
  StreamSubscription<List<int>>? _rxSub;
  final _incoming = StreamController<Uint8List>.broadcast();
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Future<bool> connect() async {
    try {
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        return false;
      }
      // Find a NUS device: prefer one already connected/bonded, else scan.
      BluetoothDevice? found;
      for (final d in FlutterBluePlus.connectedDevices) {
        found = d;
        break;
      }
      if (found == null) {
        final completer = Completer<BluetoothDevice?>();
        final sub = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            if (r.advertisementData.serviceUuids.contains(NusUuids.service)) {
              if (!completer.isCompleted) completer.complete(r.device);
              return;
            }
          }
        });
        await FlutterBluePlus.startScan(
          withServices: [NusUuids.service],
          timeout: const Duration(seconds: 8),
        );
        found = await completer.future
            .timeout(const Duration(seconds: 9), onTimeout: () => null);
        await sub.cancel();
        await FlutterBluePlus.stopScan();
      }
      if (found == null) return false;

      _device = found;
      await found.connect(autoConnect: false, timeout: const Duration(seconds: 12));
      final services = await found.discoverServices();
      for (final s in services) {
        if (s.uuid != NusUuids.service) continue;
        for (final c in s.characteristics) {
          if (c.uuid == NusUuids.tx) _tx = c;
          if (c.uuid == NusUuids.rx) {
            await c.setNotifyValue(true);
            _rxSub = c.lastValueStream.listen((bytes) {
              if (bytes.isNotEmpty && !_incoming.isClosed) {
                _incoming.add(Uint8List.fromList(bytes));
              }
            });
          }
        }
      }
      _connected = _tx != null && _rxSub != null;
      if (!_connected) await disconnect();
      return _connected;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FlutterBlueUartPort.connect failed: $e');
      }
      await disconnect();
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _rxSub?.cancel();
    _rxSub = null;
    _tx = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }

  @override
  Future<bool> write(Uint8List data) async {
    final tx = _tx;
    if (tx == null || !_connected) return false;
    try {
      // Write without response: LoRa is best-effort and this keeps throughput
      // up; the mesh's own ACK/retry handles reliability end-to-end.
      await tx.write(data, withoutResponse: tx.properties.writeWithoutResponse);
      return true;
    } catch (_) {
      return false;
    }
  }
}
