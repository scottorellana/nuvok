import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/depot/map_catalog.dart';
import 'package:nuvok/modules/depot/starter_plan.dart';

/// El instalador ahora llega ligero (~300 MB): el primer arranque debe
/// proponer QUÉ descargar sin que el usuario sepa de modelos ni de RAM.
/// Esta es la lógica pura detrás de la página "Prepara tu Nuvok".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // rootBundle en el test del catálogo
  const gb = 1024 * 1024 * 1024;

  group('qué modelo de IA proponer para descargar', () {
    test('escritorio con RAM de sobra → el especialista grande (E4B)', () {
      final m = resolveStarterModel(isDesktop: true, freeRamBytes: 16 * gb);
      expect(m.id, 'general-e4b');
    });

    test('escritorio con 6 GB libres → E2B (el E4B ya no cabe seguro)', () {
      final m = resolveStarterModel(isDesktop: true, freeRamBytes: 6 * gb);
      expect(m.id, 'general-e2b');
    });

    test('teléfono con mucha RAM libre → E2B, el especialista de móvil', () {
      final m = resolveStarterModel(isDesktop: false, freeRamBytes: 6 * gb);
      expect(m.id, 'general-e2b');
    });

    test('teléfono con 2 GB libres → Qwen 1.5B', () {
      final m = resolveStarterModel(isDesktop: false, freeRamBytes: 2 * gb);
      expect(m.id, 'general-1.5b');
    });

    test('teléfono con 700 MB libres → el 0.5B de respaldo', () {
      final m = resolveStarterModel(
          isDesktop: false, freeRamBytes: 700 * 1024 * 1024);
      expect(m.id, 'general-0.5b');
    });

    test('con RAM ínfima igual propone el más chico: nunca null', () {
      // Proponer NADA dejaría los especialistas muertos para siempre; el
      // 0.5B al menos responde con las guías literales.
      final m = resolveStarterModel(
          isDesktop: false, freeRamBytes: 100 * 1024 * 1024);
      expect(m.id, 'general-0.5b');
    });

    test('RAM desconocida → un escalón bajo el default de la plataforma', () {
      // Sin medición no se puede proponer un 3.4 GB a ciegas en un teléfono:
      // si no lo aguanta, son gigas de descarga tirados a la basura.
      expect(resolveStarterModel(isDesktop: false, freeRamBytes: null).id,
          'general-1.5b');
      expect(resolveStarterModel(isDesktop: true, freeRamBytes: null).id,
          'general-e2b');
    });

    test('usa el mismo margen de seguridad que el runtime (80%)', () {
      // El E2B pesa 3.19 GiB → necesita 3.19/0.8 = 3.99 GiB libres:
      // justo debajo no cabe, justo encima sí.
      final justoDebajo =
          resolveStarterModel(isDesktop: false, freeRamBytes: (3.9 * gb).round());
      final justoEncima =
          resolveStarterModel(isDesktop: false, freeRamBytes: (4.1 * gb).round());
      expect(justoDebajo.id, 'general-1.5b');
      expect(justoEncima.id, 'general-e2b');
    });
  });

  group('qué mapa sugerir según el país del dispositivo', () {
    test('país con región en el catálogo', () {
      expect(suggestedRegionId('HN'), 'honduras');
      expect(suggestedRegionId('VE'), 'venezuela');
      expect(suggestedRegionId('ES'), 'espana');
    });

    test('acepta minúsculas (los locales varían por plataforma)', () {
      expect(suggestedRegionId('hn'), 'honduras');
    });

    test('país sin región o desconocido → null (la página oculta la tarjeta)',
        () {
      expect(suggestedRegionId('ZZ'), isNull);
      expect(suggestedRegionId(null), isNull);
      expect(suggestedRegionId(''), isNull);
    });

    test('cada región sugerida existe de verdad en el catálogo', () async {
      final regions = (await MapCatalog.load()).map((r) => r.id).toSet();
      for (final entry in isoToRegion.entries) {
        expect(regions, contains(entry.value),
            reason: '${entry.key} sugiere "${entry.value}", que no está en '
                'assets/map_catalog.json: la sugerencia moriría en silencio');
      }
    });
  });

  group('las peticiones de descarga que arma la página', () {
    test('el modelo trae url, destino en models/ y checksum verificable', () {
      final reqs = starterDownloadRequests(
        model: resolveStarterModel(isDesktop: false, freeRamBytes: 6 * gb),
        wikiUrl: null,
        wikiBytes: null,
      );
      expect(reqs, hasLength(1));
      final r = reqs.single;
      expect(r.url, startsWith('https://'));
      expect(r.relativeDir, 'models');
      expect(r.fileName, endsWith('.gguf'));
      expect(r.sha256Hex, matches(RegExp(r'^[a-f0-9]{64}$')),
          reason: 'sin checksum la descarga no es verificable');
    });

    test('con Wikipedia resuelta añade el zim', () {
      final reqs = starterDownloadRequests(
        model: resolveStarterModel(isDesktop: false, freeRamBytes: 6 * gb),
        wikiUrl: 'https://download.kiwix.org/zim/wikipedia_es_medicine.zim',
        wikiBytes: 649222973,
      );
      expect(reqs, hasLength(2));
      expect(reqs.last.relativeDir, 'zim');
      expect(reqs.last.fileName, 'wikipedia_es_medicine.zim');
      expect(reqs.last.totalBytes, 649222973);
    });
  });
}
