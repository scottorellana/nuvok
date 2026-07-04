import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/mesh_channel.dart';
import 'package:prepper_pad/modules/mesh/mesh_envelope.dart';

void main() {
  group('MeshType.ack', () {
    test('ack type exists and is distinct from chat', () {
      expect(MeshType.values, contains(MeshType.ack));
      expect(MeshType.ack, isNot(MeshType.chat));
    });

    test('ack envelope encodes/decodes correctly', () {
      final env = MeshEnvelope(
        msgId: 42,
        channelId: 'deadbeef',
        senderId: '0123456789abcdef',
        senderName: 'Test',
        type: MeshType.ack,
        hopLimit: 1,
        timestampMs: 1234567890,
        payload: Uint8List.fromList([1, 2, 3, 4]),
      );
      final bytes = env.encode();
      final decoded = MeshEnvelope.decode(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.type, MeshType.ack);
      expect(decoded.msgId, 42);
      expect(decoded.hopLimit, 1);
    });

    test('ack payload preserves ack msgId in plaintext emergency channel',
        () async {
      // Emergency channel is plaintext by design, so ACKs on it are readable.
      final channel = MeshChannel.emergency;
      final payload = await sealPayload({'ack': 12345}, channel);
      final opened = await openPayload(payload, channel);
      expect(opened, isNotNull);
      expect(opened!['ack'], 12345);
    });
  });
}
