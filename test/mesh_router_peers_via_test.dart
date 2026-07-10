import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_channel.dart';
import 'package:nuvok/modules/mesh/mesh_envelope.dart';
import 'package:nuvok/modules/mesh/mesh_router.dart';
import 'package:nuvok/modules/mesh/mesh_store.dart';
import 'package:nuvok/modules/mesh/mesh_transport.dart';

/// Transporte en memoria con nombre configurable, para distinguir por cuál
/// llegó cada datagrama.
class _NamedFakeTransport implements MeshTransport {
  _NamedFakeTransport(this.name);
  @override
  final String name;
  final _incoming = StreamController<Uint8List>.broadcast();

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List datagram) async {}
  @override
  Stream<Uint8List> get onData => _incoming.stream;

  void inject(Uint8List datagram) => _incoming.add(datagram);
}

void main() {
  test('peersVia cuenta pares por el transporte que los oyó', () async {
    final tmp = Directory.systemTemp.createTempSync('mesh_via_test');
    final ble = _NamedFakeTransport('ble');
    final lan = _NamedFakeTransport('lan');
    final canal = MeshChannel.create('Familia');
    final router = MeshRouter(
      deviceId: 'aaaaaaaaaaaaaaaa',
      transports: [ble, lan],
      channels: [canal],
      store: MeshStore(tmp.path),
    );
    await router.start();

    // Un chat del par bb… llega por BLE.
    final env = MeshEnvelope(
      msgId: MeshEnvelope.newMsgId(),
      channelId: canal.id,
      senderId: 'bbbbbbbbbbbbbbbb',
      senderName: 'Par BLE',
      type: MeshType.chat,
      hopLimit: 3,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      payload: await sealPayload(const {'text': 'hola'}, canal),
    );
    ble.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(router.peersVia('ble'), 1);
    expect(router.peersVia('lan'), 0);
    expect(router.peersVia('inexistente'), 0);
    await router.stop();
  });
}
