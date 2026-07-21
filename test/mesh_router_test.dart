import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_channel.dart';
import 'package:nuvok/modules/mesh/mesh_envelope.dart';
import 'package:nuvok/modules/mesh/mesh_router.dart';
import 'package:nuvok/modules/mesh/mesh_store.dart';
import 'package:nuvok/modules/mesh/mesh_transport.dart';

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
  return MeshEnvelope.sealed(
    msgId: msgId ?? MeshEnvelope.newMsgId(),
    channelId: channel.id,
    senderId: senderId,
    senderName: 'Otro',
    type: type,
    hopLimit: hopLimit,
    timestampMs: DateTime.now().millisecondsSinceEpoch,
    body: payload,
    channel: channel,
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
    router.debugRelayJitter = (_) => Duration.zero;
    final env2 =
        await makeEnvelope(channel: familia, senderId: otherId, hopLimit: 2);
    transport.inject(env2.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(transport.sent, hasLength(1), reason: 'debe relevar hop 2→1');
    expect(MeshEnvelope.decode(transport.sent.first)!.hopLimit, 1);

    transport.sent.clear();
    final env0 =
        await makeEnvelope(channel: familia, senderId: otherId, hopLimit: 0);
    transport.inject(env0.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(transport.sent, isEmpty, reason: 'hop 0 no se releva');
  });

  test('canal desconocido: no emite evento pero SÍ releva', () async {
    router.debugRelayJitter = (_) => Duration.zero;
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

  // Supresión de inundación (escala ~50 nodos): el relevo espera un jitter;
  // si mientras tanto la red ya repitió el mensaje, relevarlo de nuevo no
  // aporta nada y solo satura el aire — se cancela.
  test('releva con jitter: 1 copia oída → releva al vencer el jitter',
      () async {
    router.debugRelayJitter = (_) => const Duration(milliseconds: 30);
    final env =
        await makeEnvelope(channel: familia, senderId: otherId, hopLimit: 2);
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
        transport.sent
            .map((b) => MeshEnvelope.decode(b)!)
            .where((e) => e.msgId == env.msgId),
        isEmpty,
        reason: 'dentro del jitter aún no debe relevar');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final relayed = transport.sent
        .map((b) => MeshEnvelope.decode(b)!)
        .where((e) => e.msgId == env.msgId)
        .toList();
    expect(relayed, hasLength(1));
    expect(relayed.single.hopLimit, 1);
  });

  test('supresión: oír 2+ copias durante el jitter cancela el relevo',
      () async {
    router.debugRelayJitter = (_) => const Duration(milliseconds: 60);
    final env =
        await makeEnvelope(channel: familia, senderId: otherId, hopLimit: 2);
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    transport.inject(env.encode()); // otro nodo ya lo relevó
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(
        transport.sent
            .map((b) => MeshEnvelope.decode(b)!)
            .where((e) => e.msgId == env.msgId),
        isEmpty,
        reason: 'el relevo debe suprimirse si la red ya lo repitió');
  });

  test('SOS usa umbral 3: dos copias no lo suprimen', () async {
    router.debugRelayJitter = (_) => const Duration(milliseconds: 60);
    final env = await makeEnvelope(
        channel: MeshChannel.emergency,
        senderId: otherId,
        type: MeshType.sos,
        hopLimit: 3,
        payload: {'note': 'x'});
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(
        transport.sent
            .map((b) => MeshEnvelope.decode(b)!)
            .where((e) => e.msgId == env.msgId),
        hasLength(1),
        reason: 'un SOS se releva salvo saturación evidente (3+)');
  });

  test('sin peers: transmite al aire IGUAL y además encola para reenvío',
      () async {
    final env = await makeEnvelope(channel: familia, senderId: myId);
    await router.broadcast(env); // no hay peers aún
    // Antes se encolaba sin enviar → deadlock: si la recepción de beacons
    // fallaba, nunca había peers y el mensaje jamás salía. Ahora SIEMPRE
    // sale al aire (multicast/broadcast llega a quien esté escuchando ya).
    expect(transport.sent, hasLength(1),
        reason: 'debe salir al aire aunque no se haya escuchado a nadie aún');
    expect(router.outboxCount, 1,
        reason: 'y quedar en cola por si el destinatario aún no escuchaba');
    router.notePeer(otherId);
    await router.flushOutbox();
    expect(transport.sent, hasLength(2)); // 1 en vivo + 1 al drenar la cola
    expect(router.outboxCount, 0);
  });

  test('outbox offline se mantiene acotado y conserva lo más reciente',
      () async {
    for (var i = 0; i < MeshRouter.maxOutboxDatagrams + 30; i++) {
      final env = await makeEnvelope(
        channel: familia,
        senderId: myId,
        msgId: 10000 + i,
      );
      await router.broadcast(env);
    }

    expect(router.outboxCount, MeshRouter.maxOutboxDatagrams);
    transport.sent.clear(); // ignoramos los envíos en vivo; miramos el drenado
    router.notePeer(otherId);
    await router.flushOutbox();

    expect(transport.sent, hasLength(MeshRouter.maxOutboxDatagrams));
    final firstSent = MeshEnvelope.decode(transport.sent.first)!;
    final lastSent = MeshEnvelope.decode(transport.sent.last)!;
    expect(firstSent.msgId, 10030);
    expect(lastSent.msgId, 10000 + MeshRouter.maxOutboxDatagrams + 29);
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
