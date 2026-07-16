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

    // El guard de instalabilidad aplica a lo que viaja DENTRO del APK
    // (assets de Flutter). Los recursos XL (models_xl/, p.ej. Gemma 4 de
    // 3.4GB) van como recurso nativo SOLO en iOS/macOS y quedan excluidos
    // del APK, así que no cuentan contra este techo.
    final apkEntries = entries
        .where((e) => !(e['asset'] as String).contains('/models_xl/'))
        .toList();
    final apkBytes = apkEntries.fold<int>(
      0,
      (sum, e) => sum + (e['bytes'] as num).toInt(),
    );
    final kinds = entries.map((e) => e['kind'] as String).toSet();

    expect(kinds, containsAll(['maps', 'zim', 'models']));
    expect(entries.where((e) => e['kind'] == 'maps').length,
        greaterThanOrEqualTo(2));
    expect(apkBytes, greaterThan(1024 * 1024 * 1024),
        reason: 'la instalación única debe traer contenido offline real');
    expect(apkBytes, lessThan(2 * 1024 * 1024 * 1024),
        reason:
            'mantener el APK instalable; lo que exceda va en models_xl '
            '(recurso nativo iOS/macOS) o en edición maxi');
    // Y todo entry XL debe estar efectivamente fuera del alcance del APK.
    for (final e in entries.where(
        (e) => (e['bytes'] as num) > 2 * 1024 * 1024 * 1024)) {
      expect((e['asset'] as String).contains('/models_xl/'), isTrue,
          reason: 'assets >2GB deben vivir en models_xl/, no en el APK');
    }
  });
}
