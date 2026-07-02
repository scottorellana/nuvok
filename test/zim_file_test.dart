import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/zim/zim_file.dart';

void main() {
  const fixture = 'test/fixtures/mini.zim';

  group('ZimFile', () {
    test('abre el archivo y lee la cabecera', () async {
      final zim = await ZimFile.open(fixture);
      expect(zim.header.majorVersion, greaterThanOrEqualTo(5));
      expect(zim.header.entryCount, greaterThan(0));
      expect(zim.header.clusterCount, greaterThan(0));
      expect(zim.mimeTypes, isNotEmpty);
      await zim.close();
    });

    test('lee metadatos del libro', () async {
      final zim = await ZimFile.open(fixture);
      final title = await zim.metadata('Title');
      expect(title, isNotNull);
      expect(title, isNotEmpty);
      await zim.close();
    });

    test('resuelve la página principal y descomprime su contenido', () async {
      final zim = await ZimFile.open(fixture);
      final main = await zim.mainPage();
      expect(main, isNotNull);
      final blob = await zim.contentOf(main!);
      expect(blob, isNotNull);
      expect(blob!.mimeType, startsWith('text/html'));
      final html = utf8.decode(blob.data, allowMalformed: true);
      expect(html.toLowerCase(), contains('<html'));
      await zim.close();
    });

    test('búsqueda por prefijo de título devuelve resultados', () async {
      final zim = await ZimFile.open(fixture);
      // La Wikipedia mini incluye artículos que empiezan con letras comunes.
      final results = await zim.suggest('a', limit: 10);
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.entry.isRedirect, isFalse);
      }
      await zim.close();
    });

    test('entryByPath encuentra una entrada existente', () async {
      final zim = await ZimFile.open(fixture);
      final main = await zim.mainPage();
      final found = await zim.entryByPath(main!.namespace, main.url);
      expect(found, isNotNull);
      expect(found!.index, main.index);
      await zim.close();
    });

    test('lee el contenido de varios artículos sin errores', () async {
      final zim = await ZimFile.open(fixture);
      final results = await zim.suggest('a', limit: 5);
      for (final r in results) {
        final blob = await zim.contentOf(r.entry);
        expect(blob, isNotNull, reason: 'sin contenido: ${r.path}');
        expect(blob!.data, isNotEmpty);
      }
      await zim.close();
    });

    test('archivo corrupto lanza ZimException', () async {
      expect(
        () => ZimFile.open('test/fixtures/../zim_file_test.dart'),
        throwsA(isA<ZimException>()),
      );
    });
  });
}
