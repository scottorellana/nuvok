import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_channel.dart';

void main() {
  final key = Uint8List.fromList(List<int>.generate(32, (index) => index));

  test('NUVOK1 code round-trips channel name and key', () {
    final original = MeshChannel(name: 'Familia Norte', key: key);

    final decoded = MeshChannel.fromCode(original.toCode());

    expect(decoded, isNotNull);
    expect(decoded!.name, original.name);
    expect(base64.encode(decoded.key), base64.encode(original.key));
  });

  test('legacy PPMESH1 codes remain importable', () {
    final current = MeshChannel(name: 'Familia Norte', key: key).toCode();
    final legacy = 'PPMESH1:${current.substring('NUVOK1:'.length)}';

    final decoded = MeshChannel.fromCode(legacy);

    expect(decoded, isNotNull);
    expect(decoded!.name, 'Familia Norte');
    expect(base64.encode(decoded.key), base64.encode(key));
  });
}
