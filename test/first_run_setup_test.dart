import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/depot/first_run_setup.dart';
import 'package:nuvok/modules/depot/kiwix_catalog.dart';
import 'package:nuvok/modules/depot/starter_pack.dart';
import 'package:nuvok/modules/depot/starter_plan.dart';

/// "Prepara tu Nuvok": el instalador ligero llega sin IA/mapas/enciclopedia
/// y esta página propone descargarlos en el primer arranque. Todo entra por
/// costuras inyectables: nada de red ni de disco en estos tests.
void main() {
  const gb = 1024 * 1024 * 1024;

  StarterCandidate fakeWiki() => StarterCandidate(
        StarterPack.itemsFor('spa').first,
        CatalogItem(
          title: 'Wikipedia Médica (español)',
          summary: 'Enciclopedia médica offline',
          url: 'https://download.kiwix.org/zim/wikipedia_es_medicine.zim',
          sizeBytes: 649222973,
        ),
      );

  /// Monta la página DENTRO de una ruta empujada, como en la app real, para
  /// poder verificar que se cierra sola tras encolar.
  Future<void> pumpSetup(
    WidgetTester tester, {
    required FirstRunSetupPage page,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => page)),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('propone el modelo según la RAM y arma la descarga completa',
      (tester) async {
    final got = <StarterDownloadRequest>[];
    var wentToDownloads = false;
    await pumpSetup(tester,
        page: FirstRunSetupPage(
          freeRam: () async => 2 * gb,
          isDesktop: false,
          localeCountry: 'HN',
          resolveWiki: () async => fakeWiki(),
          enqueue: got.add,
          onGoDownloads: () => wentToDownloads = true,
          onGoMaps: () {},
        ));

    // Con 2 GB libres el 1.5B es lo que cabe; el nombre visible lo dice.
    expect(find.textContaining('Qwen 2.5 1.5B'), findsOneWidget);
    // La Wikipedia resuelta y el mapa del país del dispositivo.
    expect(find.textContaining('Wikipedia Médica (español)'), findsOneWidget);
    expect(find.textContaining('Honduras'), findsOneWidget);

    await tester.tap(find.textContaining('Descargar todo'));
    await tester.pumpAndSettle();

    expect(got, hasLength(2));
    expect(got.first.relativeDir, 'models');
    expect(got.first.fileName, 'qwen2.5-1.5b-instruct-q4_k_m.gguf');
    expect(got.last.relativeDir, 'zim');
    expect(got.last.fileName, 'wikipedia_es_medicine.zim');
    expect(wentToDownloads, isTrue,
        reason: 'tras encolar debe llevar a Depósito → Descargas (progreso)');
    expect(find.text('Prepara tu Nuvok'), findsNothing,
        reason: 'la página debe cerrarse sola');
  });

  testWidgets('sin internet: lo dice con honestidad y descarga solo la IA',
      (tester) async {
    final got = <StarterDownloadRequest>[];
    await pumpSetup(tester,
        page: FirstRunSetupPage(
          freeRam: () async => 6 * gb,
          isDesktop: false,
          localeCountry: 'HN',
          resolveWiki: () async => throw Exception('offline'),
          enqueue: got.add,
          onGoDownloads: () {},
          onGoMaps: () {},
        ));

    expect(find.textContaining('Sin internet ahora'), findsOneWidget);

    await tester.tap(find.textContaining('Descargar todo'));
    await tester.pumpAndSettle();

    expect(got, hasLength(1), reason: 'solo el modelo: la wiki no resolvió');
    expect(got.single.fileName, 'gemma-4-E2B-it-Q4_K_M.gguf');
  });

  testWidgets('el mapa salta al flujo de Mapas y cierra la página',
      (tester) async {
    var wentToMaps = false;
    await pumpSetup(tester,
        page: FirstRunSetupPage(
          freeRam: () async => 2 * gb,
          isDesktop: false,
          localeCountry: 'VE',
          resolveWiki: () async => fakeWiki(),
          enqueue: (_) {},
          onGoDownloads: () {},
          onGoMaps: () => wentToMaps = true,
        ));

    expect(find.textContaining('Venezuela'), findsOneWidget);
    await tester.tap(find.text('Elegir en Mapas'));
    await tester.pumpAndSettle();
    expect(wentToMaps, isTrue);
    expect(find.text('Prepara tu Nuvok'), findsNothing);
  });

  testWidgets('"Ahora no" cierra sin encolar nada', (tester) async {
    final got = <StarterDownloadRequest>[];
    await pumpSetup(tester,
        page: FirstRunSetupPage(
          freeRam: () async => 2 * gb,
          isDesktop: false,
          localeCountry: 'HN',
          resolveWiki: () async => fakeWiki(),
          enqueue: got.add,
          onGoDownloads: () {},
          onGoMaps: () {},
        ));

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(got, isEmpty);
    expect(find.text('Prepara tu Nuvok'), findsNothing);
  });

  group('espacio en disco', () {
    testWidgets('sin espacio: avisa cuánto falta y NO deja descargar',
        (tester) async {
      final got = <StarterDownloadRequest>[];
      await pumpSetup(tester,
          page: FirstRunSetupPage(
            freeRam: () async => 6 * gb, // propone Gemma E2B (3.2 GB)
            isDesktop: false,
            localeCountry: 'HN',
            resolveWiki: () async => fakeWiki(),
            freeDisk: () async => 1 * gb, // solo 1 GB libre
            enqueue: got.add,
            onGoDownloads: () {},
            onGoMaps: () {},
          ));

      expect(find.textContaining('No hay espacio suficiente'), findsOneWidget);
      expect(find.textContaining('GB'), findsWidgets,
          reason: 'debe decir cuánto liberar, en unidades humanas');

      await tester.tap(find.textContaining('Descargar todo'));
      await tester.pumpAndSettle();
      expect(got, isEmpty,
          reason: 'dejar intentarlo sería mentirle a quien se prepara');
    });

    testWidgets('espacio justo: advierte pero deja seguir', (tester) async {
      final got = <StarterDownloadRequest>[];
      await pumpSetup(tester,
          page: FirstRunSetupPage(
            freeRam: () async => 2 * gb, // Qwen 1.5B: ~1.1 GB
            isDesktop: false,
            localeCountry: 'HN',
            resolveWiki: () async => null, // solo el modelo
            freeDisk: () async => (1.3 * gb).round(),
            enqueue: got.add,
            onGoDownloads: () {},
            onGoMaps: () {},
          ));

      expect(find.textContaining('casi lleno'), findsOneWidget);
      await tester.tap(find.textContaining('Descargar todo'));
      await tester.pumpAndSettle();
      expect(got, hasLength(1), reason: 'advertir no es bloquear');
    });

    testWidgets('espacio de sobra: ninguna alarma', (tester) async {
      await pumpSetup(tester,
          page: FirstRunSetupPage(
            freeRam: () async => 6 * gb,
            isDesktop: false,
            localeCountry: 'HN',
            resolveWiki: () async => fakeWiki(),
            freeDisk: () async => 100 * gb,
            enqueue: (_) {},
            onGoDownloads: () {},
            onGoMaps: () {},
          ));
      expect(find.textContaining('No hay espacio'), findsNothing);
      expect(find.textContaining('casi lleno'), findsNothing);
    });

    testWidgets('disco no medible: no bloquea la preparación', (tester) async {
      final got = <StarterDownloadRequest>[];
      await pumpSetup(tester,
          page: FirstRunSetupPage(
            freeRam: () async => 6 * gb,
            isDesktop: false,
            localeCountry: 'HN',
            resolveWiki: () async => fakeWiki(),
            freeDisk: () async => null, // Windows/Linux o fallo del canal
            enqueue: got.add,
            onGoDownloads: () {},
            onGoMaps: () {},
          ));
      expect(find.textContaining('No hay espacio'), findsNothing);
      await tester.tap(find.textContaining('Descargar todo'));
      await tester.pumpAndSettle();
      expect(got, isNotEmpty);
    });
  });

  testWidgets('país sin mapa en el catálogo: la tarjeta queda genérica',
      (tester) async {
    await pumpSetup(tester,
        page: FirstRunSetupPage(
          freeRam: () async => 2 * gb,
          isDesktop: false,
          localeCountry: 'ZZ',
          resolveWiki: () async => fakeWiki(),
          enqueue: (_) {},
          onGoDownloads: () {},
          onGoMaps: () {},
        ));

    expect(find.text('Mapa sin conexión'), findsOneWidget,
        reason: 'sin sugerencia, la tarjeta ofrece elegir a mano');
    expect(find.text('Elegir en Mapas'), findsOneWidget);
  });
}
