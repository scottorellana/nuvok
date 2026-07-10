import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/nuvok_library.dart';

void main() {
  test('migrates the legacy PrepperPad library without losing files', () async {
    final sandbox = await Directory.systemTemp.createTemp('nuvok-migration-');
    addTearDown(() => sandbox.delete(recursive: true));
    final legacy = Directory('${sandbox.path}/PrepperPad');
    final current = Directory('${sandbox.path}/Nuvok');
    final note = File('${legacy.path}/notes/familia.md');
    await note.create(recursive: true);
    await note.writeAsString('datos importantes');

    final selected = await NuvokLibrary.migrateLegacyRoot(
      current: current,
      legacy: legacy,
    );

    expect(selected.path, current.path);
    expect(legacy.existsSync(), isFalse);
    expect(
      File('${current.path}/notes/familia.md').readAsStringSync(),
      'datos importantes',
    );
  });

  test('an existing Nuvok library is never overwritten by legacy data',
      () async {
    final sandbox = await Directory.systemTemp.createTemp('nuvok-existing-');
    addTearDown(() => sandbox.delete(recursive: true));
    final legacy = Directory('${sandbox.path}/PrepperPad')..createSync();
    final current = Directory('${sandbox.path}/Nuvok')..createSync();
    File('${legacy.path}/legacy.txt').writeAsStringSync('legacy');
    File('${current.path}/current.txt').writeAsStringSync('current');

    final selected = await NuvokLibrary.migrateLegacyRoot(
      current: current,
      legacy: legacy,
    );

    expect(selected.path, current.path);
    expect(File('${current.path}/current.txt').readAsStringSync(), 'current');
    expect(File('${current.path}/legacy.txt').existsSync(), isFalse);
    expect(File('${legacy.path}/legacy.txt').readAsStringSync(), 'legacy');
  });
}
