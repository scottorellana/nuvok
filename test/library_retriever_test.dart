import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/core/prepper_library.dart';
import 'package:prepper_pad/modules/ai/library_retriever.dart';

// Verifies the retriever against a real ZIM in the user's library.
// Skipped when no library is present (e.g. on CI).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keywords descarta palabras vacías y conserva términos', () {
    final k = LibraryRetriever.keywords('¿Cómo trato una quemadura grave?');
    expect(k, contains('trato'));
    expect(k, contains('quemadura'));
    expect(k, contains('grave'));
    expect(k, isNot(contains('cómo')));
    expect(k, isNot(contains('una')));
  });

  test('recupera fuentes reales de la biblioteca instalada', () async {
    final home = Platform.environment['HOME']!;
    final lib = Directory('$home/PrepperPad/zim');
    if (!lib.existsSync() ||
        lib.listSync().whereType<File>().isEmpty) {
      markTestSkipped('No hay ZIMs en la biblioteca');
      return;
    }
    await PrepperLibrary.init();
    // "animal" existe como artículo en la Wikipedia mini y la de 100.
    final sources = await LibraryRetriever.retrieve('¿Qué es un animal?');
    if (sources.isEmpty) {
      markTestSkipped('La biblioteca instalada no cubre el término de prueba');
      return;
    }
    expect(sources.length, greaterThan(0));
    for (final s in sources) {
      expect(s.text.trim(), isNotEmpty);
      expect(s.book, isNotEmpty);
      expect(s.title, isNotEmpty);
    }
    final prompt = LibraryRetriever.buildGroundedSystemPrompt(sources);
    expect(prompt, contains('[1]'));
    expect(prompt, contains('FUENTES'));
  });
}
