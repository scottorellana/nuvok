import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/mesh_channel.dart';
import 'package:prepper_pad/modules/mesh/mesh_envelope.dart';
import 'package:prepper_pad/modules/mesh/voice_note.dart';

void main() {
  test('encode/decode de payload de voz hace round-trip', () {
    final audio = Uint8List.fromList(List.generate(5000, (i) => i & 0xff));
    final payload = encodeVoicePayload(audio, 4200);
    expect(payload, isNotNull);
    final note = decodeVoicePayload(payload!);
    expect(note, isNotNull);
    expect(note!.audio, audio);
    expect(note.durationMs, 4200);
  });

  test('rechaza audio vacío o que excede el límite de fragmentación', () {
    expect(encodeVoicePayload(Uint8List(0), 100), isNull);
    final tooBig = Uint8List(maxVoiceBytes + 1);
    expect(encodeVoicePayload(tooBig, 60000), isNull);
    // El máximo exacto sí cabe.
    expect(encodeVoicePayload(Uint8List(maxVoiceBytes), 10000), isNotNull);
  });

  test('decode tolera payloads corruptos sin lanzar', () {
    expect(decodeVoicePayload(const {}), isNull);
    expect(decodeVoicePayload(const {'a': '***no-base64***', 'd': 1}), isNull);
    expect(decodeVoicePayload(const {'a': 'aGk=', 'd': 'texto'}), isNull);
  });

  test('MeshType.voice viaja en el envelope y las versiones viejas no rompen',
      () async {
    // voice debe ser el ÚLTIMO valor: los decoders viejos descartan índices
    // fuera de rango en vez de mapear el tipo equivocado.
    expect(MeshType.values.last, MeshType.voice);

    final canal = MeshChannel.create('Familia');
    final audio = Uint8List.fromList(List.generate(1000, (i) => i % 251));
    final env = MeshEnvelope(
      msgId: MeshEnvelope.newMsgId(),
      channelId: canal.id,
      senderId: 'cccccccccccccccc',
      senderName: 'Voz',
      type: MeshType.voice,
      hopLimit: 3,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      payload: await sealPayload(encodeVoicePayload(audio, 1000)!, canal),
    );
    final decoded = MeshEnvelope.decode(env.encode());
    expect(decoded, isNotNull);
    expect(decoded!.type, MeshType.voice);
    final opened = await openPayload(decoded.payload, canal);
    final note = decodeVoicePayload(opened!);
    expect(note!.audio, audio);
  });
}
