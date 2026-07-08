import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/mesh_channel.dart';
import 'package:prepper_pad/modules/mesh/mesh_envelope.dart';
import 'package:prepper_pad/modules/mesh/mesh_identity.dart';
import 'package:prepper_pad/modules/mesh/mesh_router.dart';
import 'package:prepper_pad/modules/mesh/mesh_service.dart';
import 'package:prepper_pad/modules/mesh/mesh_store.dart';
import 'package:prepper_pad/modules/mesh/mesh_transport.dart';
import 'package:prepper_pad/modules/mesh/position_store.dart';

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
  void inject(Uint8List d) => _incoming.add(d);
}

/// Reproduce el iPhone real: el SO reporta el fallo del socket DESPUÉS de
/// retornar (errno 65 asíncrono) — la excepción emerge en el event loop,
/// fuera del try síncrono del que llamó. En el campo esto MATABA
/// MeshService.start() a la mitad y dejaba el mesh muerto.
class AsyncThrowingTransport implements MeshTransport {
  @override
  String get name => 'evil';
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List datagram) async {
    await Future<void>.delayed(Duration.zero);
    throw const SocketException('Send failed',
        osError: OSError('No route to host', 65));
  }

  @override
  Stream<Uint8List> get onData => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late FakeTransport transport;
  late MeshService service;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mesh_service');
    transport = FakeTransport();
    service = MeshService.forTest(
      dirPath: tmp.path,
      transports: [transport],
      identity: MeshIdentity.create('Mi Tablet'),
    );
    await service.start();
  });

  tearDown(() async {
    await service.stop();
    tmp.deleteSync(recursive: true);
  });

  test('un transporte que lanza async NO mata el arranque (bug iPhone)',
      () async {
    final tmp2 = Directory.systemTemp.createTempSync('mesh_evil');
    addTearDown(() => tmp2.deleteSync(recursive: true));
    final good = FakeTransport();
    final evil = MeshService.forTest(
      dirPath: tmp2.path,
      transports: [AsyncThrowingTransport(), good],
      identity: MeshIdentity.create('iPhone de Scott'),
    );
    await evil.start();
    // Dejar que el fallo async del socket dispare.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(evil.running.value, isTrue,
        reason: 'el mesh debe quedar corriendo aunque un radio falle');
    expect(good.sent, isNotEmpty,
        reason: 'el beacon debe salir por los transportes sanos');
    await evil.stop();
  });

  test('al arrancar difunde un beacon de presencia', () {
    expect(transport.sent, isNotEmpty);
    final env = MeshEnvelope.decode(transport.sent.first)!;
    expect(env.type, MeshType.beacon);
    expect(env.senderName, 'Mi Tablet');
    expect(env.channelId, MeshChannel.emergency.id);
  });

  test('sendChat persiste el mensaje propio y lo emite localmente', () async {
    final ch = MeshChannel.create('Familia');
    await service.joinChannel(ch);
    final events = <MeshEvent>[];
    service.events.listen(events.add);
    await service.sendChat(ch, 'hola familia');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events.any((e) => e.payload['text'] == 'hola familia'), isTrue);
    final persisted = MeshStore(tmp.path).loadMessages(ch.id);
    expect(persisted, hasLength(1));
    expect(persisted.first['text'], 'hola familia');
    expect(persisted.first['_name'], 'Mi Tablet');
  });

  test('canales unidos antes de arrancar quedan activos al iniciar', () async {
    await service.stop();
    final cold = MeshService.forTest(
      dirPath: tmp.path,
      transports: [transport],
      identity: MeshIdentity.create('Mi Tablet'),
    );
    final ch = MeshChannel.create('Prearranque');

    await cold.joinChannel(ch);
    await cold.start();

    expect(cold.channels.map((c) => c.id), contains(ch.id));
    await cold.stop();
  });

  test('canales unidos sobreviven reinicio del servicio', () async {
    final ch = MeshChannel.create('Vecinos');
    await service.joinChannel(ch);
    await service.stop();
    await service.start();
    expect(service.channels.map((c) => c.id), contains(ch.id));
  });

  test('posición entrante alimenta el PositionStore', () async {
    final ch = MeshChannel.create('Familia');
    await service.joinChannel(ch);
    final env = MeshEnvelope(
      msgId: MeshEnvelope.newMsgId(),
      channelId: ch.id,
      senderId: 'cccccccccccccccc',
      senderName: 'Hermano',
      type: MeshType.position,
      hopLimit: 3,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      payload: await sealPayload({'lat': 15.51, 'lon': -88.02}, ch),
    );
    transport.inject(env.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final peers = PositionStore.instance.recent();
    expect(peers.any((p) => p.name == 'Hermano' && p.lat == 15.51), isTrue);
  });

  test('un chat sin ACK se reenvía; con ACK deja de reenviarse', () async {
    final ch = MeshChannel.create('Familia');
    await service.joinChannel(ch);
    transport.sent.clear();
    await service.sendChat(ch, 'importante');
    final chatEnv = transport.sent
        .map((b) => MeshEnvelope.decode(b)!)
        .firstWhere((e) => e.type == MeshType.chat);
    final afterSend = transport.sent.length;

    // Sin ACK, un pase de reintento reenvía el chat (contra pérdida de UDP).
    await service.retryUnackedForTest();
    expect(transport.sent.length, greaterThan(afterSend),
        reason: 'un chat sin confirmar debe reenviarse');

    // Llega el ACK de un peer → entregado.
    final ack = MeshEnvelope(
      msgId: MeshEnvelope.newMsgId(),
      channelId: ch.id,
      senderId: 'cccccccccccccccc',
      senderName: 'Peer',
      type: MeshType.ack,
      hopLimit: 1,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      payload: await sealPayload({'ack': chatEnv.msgId}, ch),
    );
    transport.inject(ack.encode());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.isDelivered(chatEnv.msgId), isTrue);

    // Ya entregado → no se reenvía más.
    final beforeFinal = transport.sent.length;
    await service.retryUnackedForTest();
    expect(transport.sent.length, beforeFinal,
        reason: 'ya confirmado, no debe reenviarse');
  });

  test('el reenvío se detiene tras el máximo de intentos', () async {
    final ch = MeshChannel.create('Familia');
    await service.joinChannel(ch);
    transport.sent.clear();
    await service.sendChat(ch, 'x');
    for (var i = 0; i < 20; i++) {
      await service.retryUnackedForTest();
    }
    final chats = transport.sent
        .where((b) => MeshEnvelope.decode(b)!.type == MeshType.chat)
        .length;
    expect(chats, lessThanOrEqualTo(MeshService.maxChatSends),
        reason: 'no debe reenviar para siempre');
  });

  test('beacon adaptativo: 15s con peers cerca, 60s en reposo', () {
    expect(MeshService.beaconInterval(peersNearby: true),
        const Duration(seconds: 15));
    expect(MeshService.beaconInterval(peersNearby: false),
        const Duration(seconds: 60));
  });

  test('SOS entrante queda marcado y sosCancel lo limpia', () async {
    final sos = MeshEnvelope(
      msgId: MeshEnvelope.newMsgId(),
      channelId: MeshChannel.emergency.id,
      senderId: 'dddddddddddddddd',
      senderName: 'Vecina',
      type: MeshType.sos,
      hopLimit: 5,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      payload: await sealPayload(
          {'lat': 15.49, 'lon': -88.01, 'note': 'atrapada'},
          MeshChannel.emergency),
    );
    transport.inject(sos.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    var peer = PositionStore.instance.peers.value['dddddddddddddddd'];
    expect(peer, isNotNull);
    expect(peer!.isSos, isTrue);
    expect(peer.sosNote, 'atrapada');

    final cancel = MeshEnvelope(
      msgId: MeshEnvelope.newMsgId(),
      channelId: MeshChannel.emergency.id,
      senderId: 'dddddddddddddddd',
      senderName: 'Vecina',
      type: MeshType.sosCancel,
      hopLimit: 5,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      payload: await sealPayload({'ok': true}, MeshChannel.emergency),
    );
    transport.inject(cancel.encode());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    peer = PositionStore.instance.peers.value['dddddddddddddddd'];
    expect(peer!.isSos, isFalse);
  });
}
