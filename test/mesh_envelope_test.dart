import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/mesh_channel.dart';
import 'package:prepper_pad/modules/mesh/mesh_envelope.dart';

// Sobre binario de Prepper Mesh + canales cifrados. El mismo sobre viaja por
// WiFi/BT/LoRa, así que el formato debe ser estable y compacto.
void main() {
  group('MeshChannel', () {
    test('create genera claves distintas y códigos round-trip', () {
      final a = MeshChannel.create('Familia');
      final b = MeshChannel.create('Familia');
      expect(a.key, isNot(equals(b.key)));
      final back = MeshChannel.fromCode(a.toCode());
      expect(back, isNotNull);
      expect(back!.name, 'Familia');
      expect(back.key, a.key);
      expect(back.id, a.id);
    });

    test('código corrupto devuelve null', () {
      expect(MeshChannel.fromCode('PPMESH1:basura!!'), isNull);
      expect(MeshChannel.fromCode('otracosa'), isNull);
    });

    test('canal de emergencia es fijo y sin cifrar', () {
      expect(MeshChannel.emergency.isEmergency, isTrue);
      expect(MeshChannel.emergency.id, MeshChannel.emergency.id);
      expect(MeshChannel.create('x').isEmergency, isFalse);
    });
  });

  group('MeshEnvelope', () {
    test('encode → decode preserva todos los campos', () {
      final env = MeshEnvelope(
        msgId: 0x1122334455667788,
        channelId: 'abcd1234',
        senderId: 'a1b2c3d4e5f60718',
        senderName: 'Tablet de Papá',
        type: MeshType.chat,
        hopLimit: 3,
        timestampMs: 1751500000000,
        payload: Uint8List.fromList([1, 2, 3, 4, 5]),
      );
      final decoded = MeshEnvelope.decode(env.encode());
      expect(decoded, isNotNull);
      expect(decoded!.msgId, env.msgId);
      expect(decoded.channelId, env.channelId);
      expect(decoded.senderId, env.senderId);
      expect(decoded.senderName, 'Tablet de Papá');
      expect(decoded.type, MeshType.chat);
      expect(decoded.hopLimit, 3);
      expect(decoded.timestampMs, env.timestampMs);
      expect(decoded.payload, env.payload);
    });

    test('decode de basura devuelve null', () {
      expect(MeshEnvelope.decode(Uint8List.fromList([1, 2, 3])), isNull);
      expect(MeshEnvelope.decode(Uint8List.fromList(List.filled(64, 0xFF))),
          isNull);
    });

    test('withHop devuelve copia con hopLimit decrementado', () {
      final env = MeshEnvelope(
        msgId: 7,
        channelId: 'abcd1234',
        senderId: 'a1b2c3d4e5f60718',
        senderName: 'x',
        type: MeshType.position,
        hopLimit: 2,
        timestampMs: 0,
        payload: Uint8List(0),
      );
      expect(env.withHop(1).hopLimit, 1);
      expect(env.withHop(1).msgId, 7);
    });
  });

  group('cifrado de payload', () {
    test('seal → open round-trip en canal cifrado', () async {
      final ch = MeshChannel.create('Familia');
      final sealed = await sealPayload({'text': 'hola mündo ñ'}, ch);
      final opened = await openPayload(sealed, ch);
      expect(opened, isNotNull);
      expect(opened!['text'], 'hola mündo ñ');
    });

    test('clave equivocada devuelve null', () async {
      final a = MeshChannel.create('Familia');
      final b = MeshChannel.create('Familia'); // otra clave
      final sealed = await sealPayload({'text': 'secreto'}, a);
      expect(await openPayload(sealed, b), isNull);
    });

    test('emergencia va en claro y siempre se puede leer', () async {
      final sealed = await sealPayload({'sos': true}, MeshChannel.emergency);
      final opened = await openPayload(sealed, MeshChannel.emergency);
      expect(opened!['sos'], isTrue);
    });
  });
}
