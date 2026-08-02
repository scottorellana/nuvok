import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_envelope.dart';
import 'package:nuvok/modules/mesh/sos_auth.dart';
import 'package:nuvok/modules/mesh/sos_carry.dart';

void main() {
  var now = DateTime(2026, 7, 27, 12, 0);
  late SosCarry carry;

  /// Secreto de la vecina cuyo SOS llevamos encima. Solo ella lo conoce.
  late String secret;

  /// El payload del canal de emergencia va en claro por diseño: quien lanza el
  /// SOS publica la HUELLA de su secreto, y para cancelar revela el secreto.
  Uint8List plain(Map<String, Object?> json) =>
      Uint8List.fromList(utf8.encode(jsonEncode(json)));

  MeshEnvelope env(MeshType type,
          {int? msgId,
          String sender = 'aaaa1111bbbb2222',
          Map<String, Object?>? payload}) =>
      MeshEnvelope(
        msgId: msgId ?? MeshEnvelope.newMsgId(),
        channelId: 'abcd1234',
        senderId: sender,
        senderName: 'Vecina',
        type: type,
        hopLimit: 3,
        timestampMs: now.millisecondsSinceEpoch,
        payload: plain(payload ??
            switch (type) {
              MeshType.sos => {sosCommitmentKey: sosCommitmentFor(secret)},
              MeshType.sosCancel => {sosSecretKey: secret},
              _ => const {},
            }),
      );

  setUp(() {
    now = DateTime(2026, 7, 27, 12, 0);
    secret = newSosSecret();
    carry = SosCarry(clock: () => now);
  });

  group('qué se lleva encima', () {
    test('lleva un SOS ajeno para entregarlo a quien llegue después', () {
      carry.offer(env(MeshType.sos));
      expect(carry.pending.length, 1);
    });

    test('NO lleva el chat de otros: es privado y no es una emergencia', () {
      carry.offer(env(MeshType.chat));
      carry.offer(env(MeshType.position));
      carry.offer(env(MeshType.beacon));
      expect(carry.pending, isEmpty,
          reason: 'solo el SOS justifica ocupar memoria y aire ajeno');
    });

    test('no duplica el mismo mensaje', () {
      final e = env(MeshType.sos, msgId: 42);
      carry.offer(e);
      carry.offer(e);
      expect(carry.pending.length, 1);
    });
  });

  group('una cancelación detiene la propagación', () {
    test('el sosCancel del mismo remitente descarta su SOS', () {
      carry.offer(env(MeshType.sos, sender: 'aaaa1111bbbb2222'));
      expect(carry.pending.length, 1);

      carry.offer(env(MeshType.sosCancel, sender: 'aaaa1111bbbb2222'));

      expect(carry.pending.where((p) => p.type == MeshType.sos), isEmpty,
          reason: 'si ya está a salvo, seguir gritando su SOS es dañino');
    });

    test('una cancelación SIN el secreto no suelta el SOS de nadie', () {
      // El ataque: un tercero oye el SOS, ve el senderId en claro en la
      // cabecera y reemite un sosCancel con él. Para quien ya salió del rango
      // de la víctima este borrado sería irreversible: el rescatista que pase
      // después no recibiría nada.
      carry.offer(env(MeshType.sos, sender: 'aaaa1111bbbb2222'));
      carry.offer(env(MeshType.sosCancel,
          sender: 'aaaa1111bbbb2222', payload: {'ok': true}));

      expect(carry.pending.where((p) => p.type == MeshType.sos).length, 1,
          reason: 'un desconocido acaba de hacer que dejemos de llevar el '
              'grito de auxilio de una persona real');
    });

    test('reenviar la huella como si fuera el secreto tampoco cuela', () {
      carry.offer(env(MeshType.sos, sender: 'aaaa1111bbbb2222'));
      carry.offer(env(MeshType.sosCancel,
          sender: 'aaaa1111bbbb2222',
          payload: {sosSecretKey: sosCommitmentFor(secret)}));
      expect(carry.pending.where((p) => p.type == MeshType.sos).length, 1);
    });

    test('el sosCancel de OTRO remitente no toca el SOS ajeno', () {
      carry.offer(env(MeshType.sos, sender: 'aaaa1111bbbb2222'));
      carry.offer(env(MeshType.sosCancel, sender: 'cccc3333dddd4444'));
      expect(carry.pending.where((p) => p.type == MeshType.sos).length, 1);
    });
  });

  group('límites: memoria y vigencia', () {
    test('un SOS viejo caduca y deja de reenviarse', () {
      carry.offer(env(MeshType.sos));
      now = now.add(SosCarry.ttl + const Duration(minutes: 1));
      expect(carry.pending, isEmpty,
          reason: 'un SOS de hace horas confunde más de lo que ayuda');
    });

    test('un SOS reciente sigue vigente', () {
      carry.offer(env(MeshType.sos));
      now = now.add(const Duration(minutes: 1));
      expect(carry.pending.length, 1);
    });

    test('acotado en cantidad: conserva los más recientes', () {
      for (var i = 0; i < SosCarry.maxCarried + 5; i++) {
        carry.offer(env(MeshType.sos, msgId: i));
      }
      expect(carry.pending.length, SosCarry.maxCarried);
      expect(carry.pending.map((p) => p.msgId), contains(SosCarry.maxCarried + 4));
      expect(carry.pending.map((p) => p.msgId), isNot(contains(0)));
    });
  });

  group('entrega a un vecino nuevo', () {
    test('devuelve los bytes listos para reenviar', () {
      carry.offer(env(MeshType.sos));
      final out = carry.datagramsToForward();
      expect(out.length, 1);
      expect(MeshEnvelope.decode(out.first)!.type, MeshType.sos);
    });

    test('el reenvío conserva saltos disponibles', () {
      carry.offer(env(MeshType.sos));
      final decoded = MeshEnvelope.decode(carry.datagramsToForward().first)!;
      expect(decoded.hopLimit, greaterThan(0),
          reason: 'sin saltos el mensaje muere en el primer vecino');
    });
  });
}
