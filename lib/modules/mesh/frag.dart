// BLE fragmentation: mesh envelopes (200-600 bytes) exceed a single GATT
// write (~180 usable bytes), so they are split into frames of
// [u32 fragId][u16 seq][u16 total][chunk] and reassembled on the far side.
// Pure Dart and transport-agnostic so it can be tested exhaustively without
// any radio.
import 'dart:math';
import 'dart:typed_data';

const int fragHeaderLen = 8;

/// Splits [message] into frames that each fit in [mtu] bytes.
List<Uint8List> fragment(Uint8List message, {required int mtu}) {
  final chunk = mtu - fragHeaderLen;
  assert(chunk > 0, 'mtu must exceed the fragment header');
  final fragId = Random().nextInt(0xFFFFFFFF);
  final total = message.isEmpty ? 1 : (message.length / chunk).ceil();
  assert(total <= 0xFFFF);
  final out = <Uint8List>[];
  for (var seq = 0; seq < total; seq++) {
    final start = seq * chunk;
    final end = min(start + chunk, message.length);
    final frame = Uint8List(fragHeaderLen + end - start);
    ByteData.sublistView(frame)
      ..setUint32(0, fragId, Endian.little)
      ..setUint16(4, seq, Endian.little)
      ..setUint16(6, total, Endian.little);
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

/// Rebuilds messages from frames. Memory is bounded: at most [maxInFlight]
/// partial messages are kept, and any partial older than [timeout] is
/// dropped (its remaining fragments are simply lost — the mesh retry layer
/// re-sends the whole envelope anyway).
class Reassembler {
  Reassembler({
    this.timeout = const Duration(seconds: 10),
    this.maxInFlight = 16,
  });

  final Duration timeout;
  final int maxInFlight;
  final _partials = <int, _Partial>{};

  /// Partial messages currently buffered (for tests/diagnostics).
  int get inFlight => _partials.length;

  /// Feeds one received frame. Returns the full message when this frame
  /// completes it, null otherwise (including on garbage input).
  Uint8List? accept(Uint8List frame) {
    if (frame.length < fragHeaderLen) return null;
    final bd = ByteData.sublistView(frame);
    final fragId = bd.getUint32(0, Endian.little);
    final seq = bd.getUint16(4, Endian.little);
    final total = bd.getUint16(6, Endian.little);
    if (total == 0 || seq >= total) return null;
    _evictStale();
    var p = _partials[fragId];
    if (p == null) {
      // Insertion order doubles as age order, so evicting the first key
      // drops the oldest partial when the buffer is full.
      while (_partials.length >= maxInFlight) {
        _partials.remove(_partials.keys.first);
      }
      p = _Partial(total);
      _partials[fragId] = p;
    }
    if (p.total != total) return null; // conflicting header: corrupt frame
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
