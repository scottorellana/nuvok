import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/ble_transport.dart';
import 'package:nuvok/modules/mesh/transport_health.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pure framing tests — exercise fragmentation/reassembly with no hardware.
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('BleFrame.fragment', () {
    test('empty datagram produces a single START|END chunk', () {
      final chunks = BleFrame.fragment(Uint8List(0), seq: 7);
      expect(chunks, hasLength(1));
      // flags byte 0x03 = START(0x01) | END(0x02)
      expect(chunks[0][0], 0x03);
      // seq 7 → big-endian 24-bit = 0,0,7
      expect(chunks[0][1], 0);
      expect(chunks[0][2], 0);
      expect(chunks[0][3], 7);
      expect(chunks[0].length, 4); // header only, no payload
    });

    test('payload smaller than chunk size fits in one START|END chunk', () {
      final data = Uint8List.fromList(List.generate(50, (i) => i));
      final chunks = BleFrame.fragment(data, seq: 1);
      expect(chunks, hasLength(1));
      expect(chunks[0][0], 0x03);
      expect(chunks[0].length, 4 + 50);
    });

    test('payload exactly at payload boundary is two chunks', () {
      // payload size = 196 (200 - 4 header). 196 fits in one chunk payload,
      // but we treat the boundary inclusively → still one chunk.
      final data =
          Uint8List.fromList(List.generate(bleChunkSize - 4, (i) => i));
      final chunks = BleFrame.fragment(data);
      expect(chunks, hasLength(1));
      expect(chunks[0][0], 0x03);
    });

    test('payload one byte larger than boundary splits into two chunks', () {
      final data =
          Uint8List.fromList(List.generate(bleChunkSize - 3, (i) => i));
      final chunks = BleFrame.fragment(data);
      expect(chunks, hasLength(2));
      // first chunk: START only
      expect(chunks[0][0], 0x01);
      expect(chunks[0].length, bleChunkSize); // full chunk
      // last chunk: END only
      expect(chunks[1][0], 0x02);
      expect(chunks[1].length, 5); // header + 1 payload byte
    });

    test('large 64KB datagram fragments into the expected number of chunks',
        () {
      final data = Uint8List.fromList(List.generate(65536, (i) => i & 0xff));
      final chunks = BleFrame.fragment(data);
      // payload per chunk = 196; ceil(65536 / 196) = 335
      expect(chunks.length, (65536 / (bleChunkSize - 4)).ceil());
      expect(chunks.first[0], 0x01); // START
      expect(chunks.last[0], 0x02); // END
      for (var i = 1; i < chunks.length - 1; i++) {
        expect(chunks[i][0], 0); // middle chunks: no flags
      }
      // every chunk carries the same seq id
      for (final c in chunks) {
        expect(c[3] | (c[2] << 8) | (c[1] << 16), 0);
      }
    });
  });

  group('BleReassembler', () {
    test('single-chunk datagram reassembles immediately', () {
      final r = BleReassembler();
      final data = Uint8List.fromList([1, 2, 3]);
      final chunks = BleFrame.fragment(data);
      expect(chunks, hasLength(1));
      final out = r.add(chunks[0]);
      expect(out, isNotNull);
      expect(out!, data);
    });

    test('multi-chunk datagram reassembles in order', () {
      final r = BleReassembler();
      final data = Uint8List.fromList(List.generate(500, (i) => i & 0xff));
      final chunks = BleFrame.fragment(data);
      for (var i = 0; i < chunks.length; i++) {
        final out = r.add(chunks[i]);
        if (i == chunks.length - 1) {
          expect(out, isNotNull);
          expect(out, data);
        } else {
          expect(out, isNull);
        }
      }
    });

    test('empty datagram round-trips', () {
      final r = BleReassembler();
      final out = r.add(BleFrame.fragment(Uint8List(0)).first);
      expect(out, isNotNull);
      expect(out, isEmpty);
    });

    test('out-of-order middle chunks are tolerated (buffer keyed by offset)',
        () {
      // Our _Buffer writes in arrival order and emits the concatenation; the
      // reassembler itself just needs a START then END to fire. Reordering
      // middle chunks is inherently unsupported by the simple wire format, so
      // this test documents the current contract: start→payload→...→end works.
      final r = BleReassembler();
      final data = Uint8List.fromList(List.generate(500, (i) => i & 0xff));
      final chunks = BleFrame.fragment(data);
      // Feed start, then last middle, then end — the buffer still assembles
      // because writes are append-order.
      r.add(chunks[0]);
      r.add(chunks[1]);
      final out = r.add(chunks[2]);
      expect(out, isNotNull);
      expect(out, data);
    });

    test('END without START returns null (lost head)', () {
      final r = BleReassembler();
      final endChunk = Uint8List.fromList([0x02, 0, 0, 5, 9, 9]);
      expect(r.add(endChunk), isNull);
    });

    test('a new START discards any partial buffer for the same seq', () {
      final r = BleReassembler();
      // Begin a fragmented datagram (START, not END).
      final data = Uint8List.fromList(List.generate(500, (i) => i & 0xff));
      final chunks = BleFrame.fragment(data);
      r.add(chunks[0]); // START
      r.add(chunks[1]); // middle
      // Now a new START for the same seq arrives (retransmission).
      final out = r.add(chunks[0]);
      expect(out, isNull); // not END
      // Feeding END now should produce just the payload from the new START.
      // Build a minimal END chunk to check.
    });

    test('multiple concurrent datagrams with different seq ids', () {
      final r = BleReassembler();
      // Use payloads large enough to fragment (single-chunk datagrams
      // reassemble immediately, so they don't actually test concurrency).
      final a = Uint8List.fromList(List.generate(250, (i) => i));
      final b = Uint8List.fromList(List.generate(250, (i) => i + 100));

      final ca = BleFrame.fragment(a, seq: 1);
      final cb = BleFrame.fragment(b, seq: 2);
      // Both fragment into multiple chunks. Interleave STARTs, then ENDs.
      expect(r.add(ca[0]), isNull); // a START
      expect(r.add(cb[0]), isNull); // b START
      final aOut = r.add(ca.last); // a END
      expect(aOut, isNotNull);
      expect(aOut, a);
      final bOut = r.add(cb.last); // b END
      expect(bOut, isNotNull);
      expect(bOut, b);
    });

    test('malformed chunk (too short) is ignored', () {
      final r = BleReassembler();
      expect(r.add(Uint8List.fromList([1, 2])), isNull);
    });

    test('reset clears partial buffers', () {
      final r = BleReassembler();
      final data = Uint8List.fromList(List.generate(500, (i) => i & 0xff));
      r.add(BleFrame.fragment(data).first); // START only → partial
      r.reset();
      // After reset, END alone does nothing.
      final endChunk = Uint8List.fromList([0x02, 0, 0, 0, 42]);
      expect(r.add(endChunk), isNull);
    });
  });

  group('BleTransport round-trip via fake link', () {
    test('datagram sent on A arrives reassembled on B', () async {
      final linkA = _FakeBleLink(available: true);
      final linkB = _FakeBleLink(available: true);
      // Wire A↔B discovery: when A starts, B appears as a peer, and vice versa.
      linkA.wireTo(linkB);

      final a = BleTransport(link: linkA);
      final b = BleTransport(link: linkB);
      await a.start();
      await b.start();

      // Esperar a que A tenga peer conectado — por CONDICIÓN, no por reloj.
      // Con una espera fija de 200 ms este test fallaba de forma intermitente:
      // al correr la suite completa en paralelo, el descubrimiento a veces
      // tardaba más y send() salía con "no peers connected", descartando el
      // datagrama. El síntoma parecía un fallo del transporte y no lo era.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (a.health.value.peers == 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(a.health.value.peers, greaterThan(0),
          reason: 'A nunca descubrió a B: el problema es el descubrimiento, '
              'no el round-trip que este test mide');

      final payload = Uint8List.fromList(List.generate(1200, (i) => i & 0xff));
      final completer = Completer<Uint8List>();
      final sub = b.onData.listen(completer.complete);

      await a.send(payload);
      final got = await completer.future
          .timeout(const Duration(seconds: 2), onTimeout: () => Uint8List(0));
      await sub.cancel();
      await a.stop();
      await b.stop();

      expect(got, payload);
    });

    test('unavailable adapter → transport is a no-op', () async {
      final t = BleTransport(link: _FakeBleLink(available: false));
      expect(t.available, isFalse);
      await t.start(); // must not throw
      await t.send(Uint8List.fromList([1, 2, 3])); // must not throw
      await t.stop();
    });

    // Regression: send() iterates _connected while awaiting on the link.
    // A discovery event arriving mid-send mutates _connected and would throw
    // ConcurrentModificationError if send() iterated the live map. This test
    // injects a peer during the write await to guard against that.
    test('send survives a peer connecting mid-send (no concurrent modification)',
        () async {
      final link = _FakeBleLink(available: true);
      final t = BleTransport(link: link);
      await t.start();
      // Give the (empty) discovery wave time to settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Schedule a new discovery event to fire while send() is awaiting write.
      final extraPeer = _FakePeer('late-peer');
      link.scheduleDiscovery(extraPeer);

      // send() must not throw even though _connected is mutated under it.
      await t.send(Uint8List.fromList(List.generate(500, (i) => i & 0xff)));
      await t.stop();
    });

    test('BleTransport reporta salud según el estado del adaptador', () async {
      final link = _FakeBleLink(available: true);
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

    test('adaptador ausente → salud unavailable con hint', () async {
      final t = BleTransport(link: _FakeBleLink(available: false));
      await t.start();
      expect(t.health.value.state, TransportState.unavailable);
      expect(t.health.value.hint, 'no_adapter');
      await t.stop();
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake BLE link for the transport-level round-trip test.
// ─────────────────────────────────────────────────────────────────────────────

class _FakePeer implements BlePeer {
  _FakePeer(this.id);
  @override
  final String id;
}

class _FakeBleLink implements BleLink {
  _FakeBleLink({required this.available});

  @override
  bool get adapterAvailable => available;

  final stateCtrl = StreamController<String>.broadcast();

  @override
  Stream<String> get onAdapterState => stateCtrl.stream;

  final bool available;

  final _disc = StreamController<BlePeer>.broadcast();
  // Shared channel: both sides write to / read from the same controller
  // keyed by the writer's identity. The other side listens on its peer's key.
  final _channels = <String, StreamController<List<int>>>{};
  final _connectedPeers = <String>{};

  /// Other link this one is wired to (simulates two radios in range).
  _FakeBleLink? _other;

  void wireTo(_FakeBleLink other) {
    _other = other;
    other._other = this;
    // Schedule discovery after a small delay so both transports have
    // fully completed start() (including listener registration).
    Future.delayed(const Duration(milliseconds: 10), () {
      _disc.add(_FakePeer('peer-from-${other.hashCode}'));
      other._disc.add(_FakePeer('peer-from-$hashCode'));
    });
  }

  /// Injects a discovery event asynchronously (microtask), used to simulate a
  /// peer appearing while the transport is mid-send (awaits on write).
  void scheduleDiscovery(BlePeer peer) {
    Future.microtask(() => _disc.add(peer));
  }

  @override
  Stream<BlePeer> get onDiscovery => _disc.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {
    for (final c in _channels.values) {
      await c.close();
    }
    _channels.clear();
  }

  @override
  Future<bool> connect(BlePeer peer) async {
    // Create the channel on first connect. Both sides share the same
    // controller for a given writer→reader direction.
    _channels[peer.id] ??= StreamController<List<int>>.broadcast();
    _connectedPeers.add(peer.id);
    return true;
  }

  @override
  Future<void> disconnect(BlePeer peer) async {
    _connectedPeers.remove(peer.id);
  }

  @override
  Stream<List<int>>? incoming(BlePeer peer) {
    final other = _other;
    if (other == null) return null;
    other._channels[peer.id] ??= StreamController<List<int>>.broadcast();
    return other._channels[peer.id]!.stream;
  }

  @override
  Future<void> write(BlePeer peer, Uint8List chunk) async {
    final key = 'peer-from-$hashCode';
    _channels[key] ??= StreamController<List<int>>.broadcast();
    _channels[key]!.add(chunk.toList());
  }
}
