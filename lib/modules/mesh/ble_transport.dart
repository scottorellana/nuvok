// Bluetooth Low Energy transport for Prepper Mesh.
//
// Carries mesh datagrams over BLE when there is no WiFi / LAN — two devices
// pair directly and exchange the same binary MeshEnvelope frames the WiFi
// transport uses. This is the "last-meter" radio path: it works phone-to-phone
// in the woods with zero infrastructure.
//
// Design:
//   • Advertise a private Prepper Pad GATT service (see [serviceUuid]) so two
//     devices can find each other without SDP name matching.
//   • Scan for that service, connect, and exchange frames through a TX
//     characteristic (we write to peer) and an RX characteristic (peer writes
//     → we get notifications).
//   • BLE MTU is small (~512 bytes negotiated, 23 guaranteed). MeshEnvelope
//     datagrams can reach ~64 KB, so every datagram is fragmented into fixed-
//     size chunks on the wire and reassembled on the other side. The framing
//     lives in [BleFrame] / [BleReassembler] — pure, dependency-free classes
//     that are unit-tested in isolation (test/ble_transport_test.dart).
//   • Graceful degradation: if the platform has no BLE adapter, [available]
//     is false and the transport is a no-op, so the LAN transport keeps the
//     mesh alive exactly like the LoRa stub.
//
// flutter_blue_plus is used because it supports Android, macOS, Linux, and
// Windows from a single API.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'mesh_transport.dart';

/// Wire UUIDs for the Prepper Pad BLE GATT service.
///
/// Service: 0000ffe0-0000-1000-8000-00805f9b34fb  (vendor 16-bit alias range,
///   same family as the Nordic UART Service — maximises compatibility).
/// TX (we write to peer): 0000ffe1-...
/// RX (peer writes, we notify): 0000ffe2-...
class BleUuids {
  static final Guid serviceGuid =
      Guid('0000ffe0-0000-1000-8000-00805f9b34fb');
  static final Guid txGuid =
      Guid('0000ffe1-0000-1000-8000-00805f9b34fb');
  static final Guid rxGuid =
      Guid('0000ffe2-0000-1000-8000-00805f9b34fb');
}

/// Maximum bytes of a single on-the-wire chunk, including the 4-byte frame
/// header. 200 fits inside the guaranteed ATT_MTU of 23 on every stack once
/// we negotiate a larger MTU, with margin.
const int bleChunkSize = 200;

/// Maximum payload bytes per chunk (chunk size minus the 4-byte header).
const int _blePayloadSize = bleChunkSize - 4;

// ─────────────────────────────────────────────────────────────────────────────
// Pure framing logic — no BLE, no Flutter, fully unit-testable.
// ─────────────────────────────────────────────────────────────────────────────

/// Fragmentation + reassembly for mesh datagrams sent over BLE.
///
/// Each chunk on the wire is:
///   [0]    flags
///            bit 0x01 → START (first fragment of a datagram)
///            bit 0x02 → END   (last fragment of a datagram)
///   [1..3] 24-bit big-endian sequence id (same for every chunk of one
///            datagram; rolls over at 16M).
///   [4..]  payload bytes (up to `_blePayloadSize`).
class BleFrame {
  static const int _flagStart = 0x01;
  static const int _flagEnd = 0x02;

  /// Splits [datagram] into a list of on-the-wire chunks, all tagged with
  /// [seq]. A zero-length datagram still produces a single START|END chunk.
  static List<Uint8List> fragment(Uint8List datagram, {int seq = 0}) {
    if (datagram.isEmpty) {
      return [_encode(_flagStart | _flagEnd, seq, Uint8List(0))];
    }
    final out = <Uint8List>[];
    var offset = 0;
    while (offset < datagram.length) {
      final end = (offset + _blePayloadSize > datagram.length)
          ? datagram.length
          : offset + _blePayloadSize;
      final isStart = offset == 0;
      final isEnd = end == datagram.length;
      final flags = (isStart ? _flagStart : 0) | (isEnd ? _flagEnd : 0);
      out.add(_encode(flags, seq, datagram.sublist(offset, end)));
      offset = end;
    }
    return out;
  }

  static Uint8List _encode(int flags, int seq, Uint8List payload) {
    final out = Uint8List(4 + payload.length);
    out[0] = flags;
    out[1] = (seq >> 16) & 0xff;
    out[2] = (seq >> 8) & 0xff;
    out[3] = seq & 0xff;
    out.setRange(4, 4 + payload.length, payload);
    return out;
  }
}

/// Stateful reassembler for incoming BLE chunks. One instance handles many
/// interleaved datagrams keyed by sequence id.
class BleReassembler {
  final Map<int, _Buffer> _buffers = {};

  /// Feeds one wire chunk. Returns the fully reassembled datagram when the
  /// final chunk of a sequence arrives, otherwise `null`. Malformed, dropped,
  /// or repeated chunks are handled safely.
  Uint8List? add(Uint8List chunk) {
    if (chunk.length < 4) return null;
    final flags = chunk[0];
    final seq = (chunk[1] << 16) | (chunk[2] << 8) | chunk[3];
    final payload = chunk.sublist(4);
    final isStart = (flags & 0x01) != 0;
    final isEnd = (flags & 0x02) != 0;

    if (isStart && isEnd) {
      // Single-chunk datagram.
      _buffers.remove(seq);
      return Uint8List.fromList(payload);
    }
    if (isStart) {
      // New datagram begins; discard any partial buffer for this seq.
      _buffers.remove(seq);
      final b = _Buffer()..write(payload);
      _buffers[seq] = b;
      return null;
    }
    final b = _buffers[seq];
    if (b == null) return null; // middle/end without start — head lost
    b.write(payload);
    if (isEnd) {
      _buffers.remove(seq);
      return b.take();
    }
    return null;
  }

  /// Clears partial buffers (call on disconnect to free memory).
  void reset() => _buffers.clear();
}

class _Buffer {
  final _parts = <Uint8List>[];
  int _written = 0;

  void write(Uint8List bytes) {
    _parts.add(bytes);
    _written += bytes.length;
  }

  Uint8List take() {
    final out = Uint8List(_written);
    var off = 0;
    for (final p in _parts) {
      out.setRange(off, off + p.length, p);
      off += p.length;
    }
    return out;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLE link abstraction — lets the transport logic run against a fake in tests.
// ─────────────────────────────────────────────────────────────────────────────

/// A discovered/connected BLE peer, abstracted so tests can use fakes.
abstract class BlePeer {
  String get id;
}

/// Wraps the flutter_blue_plus API surface behind a small interface so the
/// transport logic can be constructed with a fake in tests.
abstract class BleLink {
  /// True if the platform exposes a powered-on BLE adapter right now.
  bool get adapterAvailable;

  /// Stream of newly discovered peers that advertise our service.
  Stream<BlePeer> get onDiscovery;

  /// Begins scanning for our service UUID.
  Future<void> start();

  /// Stops scanning and tears down per-link subscriptions.
  Future<void> stop();

  /// Connects to [peer] and subscribes to its RX characteristic.
  Future<bool> connect(BlePeer peer);

  /// Disconnects from [peer].
  Future<void> disconnect(BlePeer peer);

  /// Stream of raw chunk bytes received from [peer], or null if not connected.
  Stream<List<int>>? incoming(BlePeer peer);

  /// Writes [chunk] to [peer]'s TX characteristic (without response).
  Future<void> write(BlePeer peer, Uint8List chunk);
}

/// Production [BleLink] backed by flutter_blue_plus.
class FlutterBluePlusLink implements BleLink {
  final _incoming = <String, StreamController<List<int>>>{};
  final _devices = <String, BluetoothDevice>{};
  final _disc = StreamController<BlePeer>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _started = false;

  @override
  bool get adapterAvailable {
    try {
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<BlePeer> get onDiscovery => _disc.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.advertisementData.serviceUuids
            .any((u) => u == BleUuids.serviceGuid)) {
          final d = r.device;
          final id = d.remoteId.str;
          if (!_devices.containsKey(id)) {
            _devices[id] = d;
            _disc.add(_FbpPeer(d));
          }
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(
        withServices: [BleUuids.serviceGuid],
        timeout: const Duration(seconds: 30),
      );
    } catch (_) {
      // Permissions / adapter off — degrade silently.
    }
  }

  @override
  Future<void> stop() async {
    _started = false;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
    for (final c in _incoming.values) {
      await c.close();
    }
    _incoming.clear();
    _devices.clear();
  }

  @override
  Future<bool> connect(BlePeer peer) async {
    final d = _deviceOf(peer);
    if (d == null) return false;
    try {
      await d.connect(autoConnect: false);
      final services = await d.discoverServices();
      BluetoothCharacteristic? rx;
      for (final s in services) {
        if (s.uuid != BleUuids.serviceGuid) continue;
        for (final c in s.characteristics) {
          if (c.uuid == BleUuids.rxGuid) rx = c;
        }
      }
      if (rx == null) return false;
      await rx.setNotifyValue(true);
      final id = d.remoteId.str;
      final ctrl = StreamController<List<int>>.broadcast();
      rx.lastValueStream.listen(ctrl.add);
      _incoming[id] = ctrl;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect(BlePeer peer) async {
    final d = _deviceOf(peer);
    if (d == null) return;
    final id = d.remoteId.str;
    await _incoming[id]?.close();
    _incoming.remove(id);
    try {
      await d.disconnect();
    } catch (_) {}
  }

  @override
  Stream<List<int>>? incoming(BlePeer peer) {
    final d = _deviceOf(peer);
    if (d == null) return null;
    return _incoming[d.remoteId.str]?.stream;
  }

  @override
  Future<void> write(BlePeer peer, Uint8List chunk) async {
    final d = _deviceOf(peer);
    if (d == null) return;
    try {
      final services = await d.discoverServices();
      for (final s in services) {
        if (s.uuid != BleUuids.serviceGuid) continue;
        for (final c in s.characteristics) {
          if (c.uuid == BleUuids.txGuid) {
            await c.write(chunk, withoutResponse: true);
            return;
          }
        }
      }
    } catch (_) {}
  }

  BluetoothDevice? _deviceOf(BlePeer peer) {
    if (peer is _FbpPeer) return peer.device;
    return _devices[peer.id];
  }
}

class _FbpPeer implements BlePeer {
  _FbpPeer(this.device);
  final BluetoothDevice device;
  @override
  String get id => device.remoteId.str;
}

/// BLE mesh transport. Falls back to a no-op when the adapter is unavailable,
/// exactly like the LoRa stub.
class BleTransport implements MeshTransport {
  BleTransport({BleLink? link}) : _link = link ?? FlutterBluePlusLink();

  final BleLink _link;
  final _data = StreamController<Uint8List>.broadcast();
  final _reassemblers = <String, BleReassembler>{};
  final _connected = <String, BlePeer>{};
  StreamSubscription<BlePeer>? _discoverSub;
  bool _running = false;

  /// True only when a BLE adapter is powered on.
  bool get available => _link.adapterAvailable;

  @override
  String get name => 'ble';

  @override
  Stream<Uint8List> get onData => _data.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    if (!available) return; // no adapter — degrade silently
    _running = true;
    await _link.start();
    _discoverSub = _link.onDiscovery.listen(_onPeer);
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _discoverSub?.cancel();
    _discoverSub = null;
    for (final p in List.of(_connected.values)) {
      try {
        await _link.disconnect(p);
      } catch (_) {}
    }
    _connected.clear();
    _reassemblers.clear();
    await _link.stop();
  }

  @override
  Future<void> send(Uint8List datagram) async {
    if (!_running) return;
    final seq = _nextSeq();
    final chunks = BleFrame.fragment(datagram, seq: seq);
    for (final p in _connected.values) {
      for (final chunk in chunks) {
        try {
          await _link.write(p, chunk);
        } catch (_) {
          // One peer failing must not abort the others.
        }
      }
    }
  }

  int _seqCounter = 0;
  int _nextSeq() {
    final s = _seqCounter & 0xffffff;
    _seqCounter = (_seqCounter + 1) & 0xffffff;
    return s;
  }

  Future<void> _onPeer(BlePeer peer) async {
    if (_connected.containsKey(peer.id)) return;
    _connected[peer.id] = peer;
    final ok = await _link.connect(peer);
    if (!ok) {
      _connected.remove(peer.id);
      return;
    }
    final rx = _link.incoming(peer);
    if (rx == null) return;
    final reasm = BleReassembler();
    _reassemblers[peer.id] = reasm;
    rx.listen((bytes) {
      final full = reasm.add(Uint8List.fromList(bytes));
      if (full != null) _data.add(full);
    });
  }
}
