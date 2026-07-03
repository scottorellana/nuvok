import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/mesh_channel.dart';
import 'package:prepper_pad/modules/mesh/mesh_envelope.dart';
import 'package:prepper_pad/modules/mesh/mesh_router.dart';
import 'package:prepper_pad/modules/mesh/mesh_store.dart';
import 'package:prepper_pad/modules/mesh/mesh_transport.dart';

/// Transporte en memoria para tests: guarda lo enviado y permite inyectar
/// datagramas entrantes.
class FakeTransport implements MeshTransport {
  final sent = <Uint8List>[];
  final _incoming = StreamController<Uint8List>.broadcast();

  @override
  String get name => 'fake';
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List datagram) async => sent.add(datagram);
  @override
  Stream<Uint8List> get onData => _incoming.stream;

  void inject(Uint8List datagram) => _incoming.add(datagram);
}

Future<MeshEnvelope> makeEnvelope({
  required MeshChannel channel,
  required String senderId,
  MeshType type = MeshType.chat,
  int hopLimit = 3,
  Map<String, dynamic> payload = const {'text': 'hola'},
  int? msgId,
}) async {
  return MeshEnvelope(
    msgId: msgId ?? MeshEnvelope.newMsgId(),
    channelId: channel.id,
    senderId: senderId,
    senderName: 'Otro',
    type: type,
    hopLimit: hopLimit,
    timestampMs: DateTime.now().millisecondsSinceEpoch,
    payload: await sealPayload(payload, channel),
  );
}

void main() {
  late Directory tmp;
  late FakeTransport transport;
  late MeshRouter router;
  late MeshChannel familia;
  const myId = 'aaaaaaaaaaaaaaaa';
  const otherId = 'bbbbbbbbbbbbbbbb';

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mesh_test');
    transport = FakeTransport();
    familia = MeshChannel.create('Familia');
    router = MeshRouter(
      deviceId: myId,
      transports: [transport],
      channels: [familia],
      store: MeshStore(tmp.path),
    );
    await router.start();
  });

  tearDown(() async {
    await router.stop();
    tmp.deleteSync(recursive: true);
  });

  test('broadcast propio sale codificado por el transporte', () async {
    final env = await makeEnvelope(channel: familia, senderId: myId);
    // Simula que hay un peer presente para que no se encole.
    router.notePeer(otherId);
    await router.broadcast(env);
    expect(transport.sent, hasLength(1));
    expect(MeshEnvelope.decode(transport.sent.first)!.msgId, env.msgId);
  });

  test('datagrama entrante emite evento con payload descifrado', () async {
    final events = <MeshEvent>[];
    router.events.listen(events.add);
    final env = await makeEnvelope(
        channel: familia, senderId: otherId, payload: {'text': 'buenas'});
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(events, hasLength(1));
    expect(events.first.payload['text'], 'buenas');
    expect(events.first.channel.id, familia.id);
  });

  test('mismo msgId dos veces → un solo evento (dedup)', () async {
    final events = <MeshEvent>[];
    router.events.listen(events.add);
    final env = await makeEnvelope(channel: familia, senderId: otherId);
    transport.inject(env.encode());
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(events, hasLength(1));
  });

  test('releva con hopLimit-1; con hopLimit 0 no releva', () async {
    final env2 = await makeEnvelope(
        channel: familia, senderId: otherId, hopLimit: 2);
    transport.inject(env2.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(transport.sent, hasLength(1), reason: 'debe relevar hop 2→1');
    expect(MeshEnvelope.decode(transport.sent.first)!.hopLimit, 1);

    transport.sent.clear();
    final env0 = await makeEnvelope(
        channel: familia, senderId: otherId, hopLimit: 0);
    transport.inject(env0.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(transport.sent, isEmpty, reason: 'hop 0 no se releva');
  });

  test('canal desconocido: no emite evento pero SÍ releva', () async {
    final events = <MeshEvent>[];
    router.events.listen(events.add);
    final ajeno = MeshChannel.create('Ajeno');
    final env =
        await makeEnvelope(channel: ajeno, senderId: otherId, hopLimit: 3);
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(events, isEmpty);
    expect(transport.sent, hasLength(1));
  });

  test('sin peers → outbox; flush al aparecer un peer', () async {
    final env = await makeEnvelope(channel: familia, senderId: myId);
    await router.broadcast(env); // no hay peers aún
    expect(transport.sent, isEmpty);
    expect(router.outboxCount, 1);
    router.notePeer(otherId);
    await router.flushOutbox();
    expect(transport.sent, hasLength(1));
    expect(router.outboxCount, 0);
  });

  test('mensajes de canal conocido se persisten y recargan', () async {
    final env = await makeEnvelope(
        channel: familia, senderId: otherId, payload: {'text': 'persistente'});
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final loaded = MeshStore(tmp.path).loadMessages(familia.id);
    expect(loaded, hasLength(1));
    expect(loaded.first['text'], 'persistente');
  });

  test('emergencia siempre se escucha aunque no esté en channels', () async {
    final events = <MeshEvent>[];
    router.events.listen(events.add);
    final env = await makeEnvelope(
        channel: MeshChannel.emergency,
        senderId: otherId,
        type: MeshType.sos,
        payload: {'lat': 15.5, 'lon': -88.0, 'note': 'ayuda'});
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(events, hasLength(1));
    expect(events.first.envelope.type, MeshType.sos);
    expect(events.first.payload['note'], 'ayuda');
  });
}
