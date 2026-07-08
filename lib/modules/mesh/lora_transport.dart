// LoRa transport — the long-range radio path for Prepper Mesh.
//
// This file contains the production wire protocol and a hardware-driver seam.
// The app can test LoRa end-to-end today with an injected driver, while real
// field deployment still requires a USB/BLE LoRa radio driver implementation.
// Until a physical radio is detected, the transport degrades silently and LAN /
// BLE / WiFi Direct continue carrying the mesh.
import 'dart:async';
import 'dart:typed_data';

import 'mesh_transport.dart';

/// Maximum on-radio frame size. 230 bytes fits common Meshtastic/LoRa payload
/// ceilings with margin for firmware headers.
const int loraMaxFrameSize = 230;

const int _loraHeaderSize = 4;
const int _loraPayloadSize = loraMaxFrameSize - _loraHeaderSize;

enum LoraLinkKind { usbSerial, bleUart }

/// Hardware driver seam. Production drivers should expose USB serial or BLE
/// UART frames here; tests can inject a fake bidirectional link.
abstract class LoraLinkDriver {
  bool get available;
  Future<bool> open();
  Future<void> close();
  Future<bool> writeFrame(Uint8List frame);
  Stream<Uint8List> get onFrame;
}

/// Default hardware-unavailable driver. It intentionally reports unavailable:
/// claiming LoRa works without an attached/validated radio would be unsafe in
/// an emergency product.
class UnavailableLoraLinkDriver implements LoraLinkDriver {
  const UnavailableLoraLinkDriver({
    this.kind = LoraLinkKind.usbSerial,
    this.portName,
  });

  final LoraLinkKind kind;
  final String? portName;

  @override
  bool get available => false;

  @override
  Stream<Uint8List> get onFrame => const Stream<Uint8List>.empty();

  @override
  Future<bool> open() async => false;

  @override
  Future<void> close() async {}

  @override
  Future<bool> writeFrame(Uint8List frame) async => false;
}

/// Fragmentation + reassembly for LoRa payloads.
///
/// Frame layout:
///   [0]    flags: 0x01 START, 0x02 END, 0x03 single-frame
///   [1..3] 24-bit big-endian sequence id
///   [4..]  payload bytes
class LoraFrame {
  static const int _flagStart = 0x01;
  static const int _flagEnd = 0x02;

  static List<Uint8List> fragment(Uint8List datagram, {int seq = 0}) {
    if (datagram.isEmpty) {
      return [_encode(_flagStart | _flagEnd, seq, Uint8List(0))];
    }
    final out = <Uint8List>[];
    var offset = 0;
    while (offset < datagram.length) {
      final end = (offset + _loraPayloadSize > datagram.length)
          ? datagram.length
          : offset + _loraPayloadSize;
      final flags = (offset == 0 ? _flagStart : 0) |
          (end == datagram.length ? _flagEnd : 0);
      out.add(
          _encode(flags, seq, Uint8List.sublistView(datagram, offset, end)));
      offset = end;
    }
    return out;
  }

  static Uint8List _encode(int flags, int seq, Uint8List payload) {
    final out = Uint8List(_loraHeaderSize + payload.length);
    out[0] = flags;
    out[1] = (seq >> 16) & 0xff;
    out[2] = (seq >> 8) & 0xff;
    out[3] = seq & 0xff;
    out.setRange(_loraHeaderSize, _loraHeaderSize + payload.length, payload);
    return out;
  }
}

class LoraReassembler {
  final _buffers = <int, _LoraBuffer>{};

  /// Cap the in-flight reassembly table. LoRa is store-and-forward: a single
  /// peer that keeps sending START frames without ENDs can grow this map
  /// unbounded. 64 in-flight datagrams is far more than a real radio link
  /// ever carries, and keeps memory bounded across long emergency sessions.
  static const int _maxInflight = 64;

  Uint8List? add(Uint8List frame) {
    if (frame.length < _loraHeaderSize || frame.length > loraMaxFrameSize) {
      return null;
    }
    final flags = frame[0];
    final seq = (frame[1] << 16) | (frame[2] << 8) | frame[3];
    final payload = Uint8List.sublistView(frame, _loraHeaderSize);
    final isStart = (flags & LoraFrame._flagStart) != 0;
    final isEnd = (flags & LoraFrame._flagEnd) != 0;

    if (isStart && isEnd) {
      _buffers.remove(seq);
      return Uint8List.fromList(payload);
    }
    if (isStart) {
      // Evict oldest in-flight buffer if we'd exceed the cap. Iterating an
      // int-keyed map preserves insertion order (LinkedHashMap), so the first
      // key is the oldest START still waiting for its END.
      if (_buffers.length >= _maxInflight && !_buffers.containsKey(seq)) {
        final oldest = _buffers.keys.first;
        _buffers.remove(oldest);
      }
      _buffers[seq] = _LoraBuffer()..write(payload);
      return null;
    }
    final buffer = _buffers[seq];
    if (buffer == null) return null;
    buffer.write(payload);
    if (isEnd) {
      _buffers.remove(seq);
      return buffer.take();
    }
    return null;
  }

  void reset() => _buffers.clear();
}

class _LoraBuffer {
  final _parts = <Uint8List>[];
  int _length = 0;

  void write(Uint8List bytes) {
    _parts.add(Uint8List.fromList(bytes));
    _length += bytes.length;
  }

  Uint8List take() {
    final out = Uint8List(_length);
    var offset = 0;
    for (final part in _parts) {
      out.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return out;
  }
}

class LoraTransport implements MeshTransport {
  LoraTransport({
    LoraLinkDriver? link,
    this.kind = LoraLinkKind.usbSerial,
    this.portName,
  }) : _link = link ??
            UnavailableLoraLinkDriver(
              kind: kind,
              portName: portName,
            );

  final LoraLinkKind kind;
  final String? portName;
  final LoraLinkDriver _link;

  final _data = StreamController<Uint8List>.broadcast();
  final _reassembler = LoraReassembler();
  StreamSubscription<Uint8List>? _framesSub;
  bool _open = false;
  int _seqCounter = 0;

  bool get available => _link.available;

  @override
  String get name => 'lora';

  @override
  Stream<Uint8List> get onData => _data.stream;

  @override
  Future<void> start() async {
    // Gate only on already-open: the driver's open() performs the actual
    // connect (BLE scan/pair), so availability isn't known until after. A
    // driver with no radio (UnavailableLoraLinkDriver) returns false from
    // open() and this no-ops cheaply.
    if (_open) return;
    // Subscribe before open: USB/BLE drivers can emit queued bytes as soon as
    // the port opens.
    _framesSub = _link.onFrame.listen((frame) {
      final full = _reassembler.add(frame);
      if (full != null && !_data.isClosed) _data.add(full);
    });
    _open = await _link.open();
    if (!_open) {
      await _framesSub?.cancel();
      _framesSub = null;
    }
  }

  @override
  Future<void> stop() async {
    _open = false;
    await _framesSub?.cancel();
    _framesSub = null;
    _reassembler.reset();
    await _link.close();
  }

  @override
  Future<void> send(Uint8List datagram) async {
    if (!_open) return;
    final seq = _nextSeq();
    for (final frame in LoraFrame.fragment(datagram, seq: seq)) {
      try {
        final ok = await _link.writeFrame(frame);
        if (!ok) return;
      } catch (_) {
        return;
      }
    }
  }

  int _nextSeq() {
    final seq = _seqCounter & 0xffffff;
    _seqCounter = (_seqCounter + 1) & 0xffffff;
    return seq;
  }
}
