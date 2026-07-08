import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled offline starter pack is complete but still installable', () {
    final manifestFile = File('assets/bundled_library/manifest.json');
    expect(manifestFile.existsSync(), isTrue);
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final entries = (manifest['entries'] as List).cast<Map<String, dynamic>>();

    final totalBytes = entries.fold<int>(
      0,
      (sum, e) => sum + (e['bytes'] as num).toInt(),
    );
    final kinds = entries.map((e) => e['kind'] as String).toSet();

    expect(kinds, containsAll(['maps', 'zim', 'models']));
    expect(entries.where((e) => e['kind'] == 'maps').length,
        greaterThanOrEqualTo(2));
    expect(totalBytes, greaterThan(1024 * 1024 * 1024),
        reason: 'la instalación única debe traer contenido offline real');
    expect(totalBytes, lessThan(2 * 1024 * 1024 * 1024),
        reason:
            'mantener el APK/DMG instalable; los ZIM gigantes van en edición maxi');
  });
}
