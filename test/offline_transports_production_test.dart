import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/ble_transport.dart';
import 'package:nuvok/modules/mesh/lora_transport.dart';
import 'package:nuvok/modules/mesh/wifi_direct_transport.dart';

void main() {
  group('production discovery timing', () {
    test('BLE does not miss peers emitted during link.start()', () async {
      final linkA = _EagerBleLink(available: true);
      final linkB = _EagerBleLink(available: true);
      linkA.wireTo(linkB);
      final a = BleTransport(link: linkA);
      final b = BleTransport(link: linkB);

      await a.start();
      await b.start();

      final received = Completer<Uint8List>();
      final sub = b.onData.listen((d) {
        if (!received.isCompleted) received.complete(d);
      });
      final payload = Uint8List.fromList(List.generate(900, (i) => i & 0xff));
      await a.send(payload);
      final got = await received.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => Uint8List(0),
      );

      await sub.cancel();
      await a.stop();
      await b.stop();
      expect(got, payload);
    });

    test('WiFi Direct does not miss endpoints emitted during link.start()',
        () async {
      final linkA = _EagerWifiLink();
      final linkB = _EagerWifiLink();
      linkA.wireTo(linkB);
      final a = WifiDirectTransport(link: linkA);
      final b = WifiDirectTransport(link: linkB);

      await a.start();
      await b.start();

      final received = Completer<Uint8List>();
      final sub = b.onData.listen((d) {
        if (!received.isCompleted) received.complete(d);
      });
      final payload = Uint8List.fromList('wifi-direct-offline'.codeUnits);
      await a.send(payload);
      final got = await received.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => Uint8List(0),
      );

      await sub.cancel();
      await a.stop();
      await b.stop();
      expect(String.fromCharCodes(got), 'wifi-direct-offline');
    });
  });

  group('LoRa production protocol', () {
    test('LoRa frames fragment and reassemble emergency-sized datagrams', () {
      final data = Uint8List.fromList(List.generate(4096, (i) => i & 0xff));
      final chunks = LoraFrame.fragment(data, seq: 42);
      expect(chunks.length, greaterThan(1));
      expect(chunks.every((c) => c.length <= loraMaxFrameSize), isTrue);

      final reassembler = LoraReassembler();
      Uint8List? out;
      for (final chunk in chunks) {
        out = reassembler.add(chunk) ?? out;
      }
      expect(out, data);
    });

    test('LoRa transport sends and receives through an injected radio link',
        () async {
      final linkA = _FakeLoraLink();
      final linkB = _FakeLoraLink();
      linkA.wireTo(linkB);
      final a = LoraTransport(link: linkA);
      final b = LoraTransport(link: linkB);
      await a.start();
      await b.start();

      final received = Completer<Uint8List>();
      final sub = b.onData.listen((d) {
        if (!received.isCompleted) received.complete(d);
      });
      final payload = Uint8List.fromList(List.generate(1200, (i) => i & 0xff));
      await a.send(payload);
      final got = await received.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => Uint8List(0),
      );

      await sub.cancel();
      await a.stop();
      await b.stop();
      expect(got, payload);
    });
  });
}

class _FakePeer implements BlePeer {
  _FakePeer(this.id);
  @override
  final String id;
}

class _EagerBleLink implements BleLink {
  _EagerBleLink({required this.available});
  final bool available;
  _EagerBleLink? _other;
  final _disc = StreamController<BlePeer>.broadcast();
  final _channels = <String, StreamController<List<int>>>{};

  void wireTo(_EagerBleLink other) {
    _other = other;
    other._other = this;
  }

  @override
  bool get adapterAvailable => available;

  @override
  Stream<String> get onAdapterState => const Stream.empty();

  @override
  Stream<BlePeer> get onDiscovery => _disc.stream;

  @override
  Future<void> start() async {
    final other = _other;
    if (other != null) {
      _disc.add(_FakePeer('peer-from-${other.hashCode}'));
    }
  }

  @override
  Future<void> stop() async {
    for (final c in _channels.values) {
      await c.close();
    }
    _channels.clear();
  }

  @override
  Future<bool> connect(BlePeer peer) async {
    _channels[peer.id] ??= StreamController<List<int>>.broadcast();
    return true;
  }

  @override
  Future<void> disconnect(BlePeer peer) async {}

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

class _EagerWifiLink implements WifiDirectLink {
  _EagerWifiLink? _other;
  final _connected = StreamController<String>.broadcast();
  final _disconnected = StreamController<String>.broadcast();
  final _payload = StreamController<Uint8List>.broadcast();
  bool started = false;

  void wireTo(_EagerWifiLink other) {
    _other = other;
    other._other = this;
  }

  @override
  bool get available => true;

  @override
  Stream<String> get onConnected => _connected.stream;

  @override
  Stream<String> get onDisconnected => _disconnected.stream;

  @override
  Stream<Uint8List> get onPayload => _payload.stream;

  @override
  Future<bool> start(String userName) async {
    started = true;
    _connected.add('peer');
    return true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Future<bool> send(String endpointId, Uint8List bytes) async {
    if (!started) return false;
    final other = _other;
    if (other == null || !other.started) return false;
    other._payload.add(Uint8List.fromList(bytes));
    return true;
  }
}

class _FakeLoraLink implements LoraLinkDriver {
  _FakeLoraLink? _other;
  final _frames = StreamController<Uint8List>.broadcast();
  bool _open = false;

  void wireTo(_FakeLoraLink other) {
    _other = other;
    other._other = this;
  }

  @override
  bool get available => true;

  @override
  Stream<Uint8List> get onFrame => _frames.stream;

  @override
  Future<bool> open() async {
    _open = true;
    return true;
  }

  @override
  Future<void> close() async {
    _open = false;
  }

  @override
  Future<bool> writeFrame(Uint8List frame) async {
    if (!_open) return false;
    final other = _other;
    if (other == null || !other._open) return false;
    other._frames.add(Uint8List.fromList(frame));
    return true;
  }
}
