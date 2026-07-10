import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS bundled asset channel copies and verifies an asset',
      (tester) async {
    if (!Platform.isMacOS) return;

    final temp = await Directory.systemTemp.createTemp('nuvok-asset-test-');
    addTearDown(() => temp.delete(recursive: true));
    final destination = File('${temp.path}/wikipedia_mini.zim');

    await const MethodChannel('nuvok/bundled_assets')
        .invokeMethod<void>('copyAsset', {
      'asset': 'assets/bundled_library/zim/wikipedia_mini.zim',
      'dest': destination.path,
      'bytes': 4537782,
      'sha256':
          '2811724b72fd34a0728c28b7456d3d6866579019fbbe7ffe28528f3450c252db',
    });

    expect(destination.existsSync(), isTrue);
    expect(destination.lengthSync(), 4537782);
    expect(File('${destination.path}.tmp').existsSync(), isFalse);
  });
}
