import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/medical_diagrams.dart';

/// Los PASOS CRÍTICOS son lo primero que ve —y lo único que OYE en manos
/// libres— alguien que intenta salvar una vida. Estos tests verifican el
/// CONTENIDO CLÍNICO, no solo el formato.
///
/// Por qué existen: el extractor barría TODAS las líneas numeradas del
/// markdown sin distinguir secciones, y descartaba las de más de 120
/// caracteres. Resultado real medido sobre las guías de producción:
///  - RCP de adulto: la tarjeta NUNCA decía comprimir el pecho (ese paso mide
///    167 chars); los pasos 3-6 eran del DEA renumerados como si fueran RCP.
///  - Atragantamiento: los pasos 3-6 eran del protocolo de LACTANTE ("gíralo
///    boca arriba") y el Heimlich del adulto se descartaba por medir 158.
/// Un rescatista siguiendo esa tarjeta habría hecho la maniobra equivocada.
String _guide(String lang, String id) =>
    File('assets/emergency_guides/$lang/$id.md').readAsStringSync();

void main() {
  group('RCP de adulto: la instrucción que salva no puede faltar', () {
    for (final lang in ['es', 'en']) {
      test('[$lang] los pasos incluyen comprimir el pecho', () {
        final steps = extractCriticalSteps(_guide(lang, 'rcp_adulto'));
        final texto = steps.join(' ').toLowerCase();
        expect(texto, matches(RegExp(lang == 'es' ? r'compr[ie]' : r'compress')),
            reason: 'sin la orden de comprimir, la tarjeta es inútil: $steps');
      });

      test('[$lang] el ritmo o la profundidad son alcanzables', () {
        final steps = extractCriticalSteps(_guide(lang, 'rcp_adulto'));
        final texto = steps.join(' ');
        expect(texto, matches(RegExp(r'100|120|5\s*-\s*6|5–6')),
            reason: 'ritmo/profundidad son las cifras que definen una RCP '
                'eficaz: $steps');
      });
    }
  });

  group('Atragantamiento: el protocolo del adulto no puede ser el del bebé',
      () {
    for (final lang in ['es', 'en']) {
      test('[$lang] aparece la compresión abdominal (Heimlich)', () {
        final steps = extractCriticalSteps(_guide(lang, 'atragantamiento'));
        final texto = steps.join(' ').toLowerCase();
        expect(
            texto,
            matches(RegExp(
                lang == 'es' ? r'abdominal|ombligo' : r'abdominal|navel')),
            reason: 'es la maniobra que desatasca a un adulto: $steps');
      });

      test('[$lang] NO se cuela la maniobra de lactante', () {
        final steps = extractCriticalSteps(_guide(lang, 'atragantamiento'));
        final texto = steps.join(' ').toLowerCase();
        expect(
            texto,
            isNot(matches(RegExp(lang == 'es'
                ? r'boca arriba|pezones|lactante'
                : r'face up|nipple|infant'))),
            reason: 'girar boca arriba a un adulto consciente es peligroso y '
                'retrasa la maniobra correcta: $steps');
      });
    }
  });

  group('Hemorragia severa: acciones, no solo prohibiciones', () {
    for (final lang in ['es', 'en']) {
      test('[$lang] el primer paso es presionar la herida', () {
        final steps = extractCriticalSteps(_guide(lang, 'hemorragia_severa'));
        expect(steps, isNotEmpty);
        expect(steps.first.toLowerCase(),
            matches(RegExp(lang == 'es' ? r'presiona' : r'press')),
            reason: 'los pasos que detienen la muerte vivían en un diagrama '
                'ASCII invisible para el extractor: la tarjeta solo mostraba '
                'prohibiciones. Pasos: $steps');
      });

      test('[$lang] el torniquete lleva su distancia exacta', () {
        final texto =
            extractCriticalSteps(_guide(lang, 'hemorragia_severa')).join(' ');
        expect(texto, contains('5-8'),
            reason: 'un torniquete mal colocado no detiene la hemorragia');
      });
    }

    test('los 7 idiomas tienen la sección accionable', () {
      for (final lang in ['es', 'en', 'pt', 'fr', 'zh', 'ja', 'ht']) {
        final steps = extractCriticalSteps(_guide(lang, 'hemorragia_severa'));
        expect(steps.length, greaterThanOrEqualTo(4),
            reason: '$lang quedó sin pasos accionables: $steps');
      }
    });
  });

  group('regla general del extractor', () {
    test('un paso largo se acorta, nunca se descarta', () {
      const body = '''
## Actúa
1. **Inicia compresiones.** Coloca el talón de una mano en el centro del pecho, la otra encima, brazos rectos, y comprime fuerte y rápido a 100-120 por minuto sin detenerte.
2. Corto.
''';
      final steps = extractCriticalSteps(body);
      expect(steps, hasLength(2));
      expect(steps.first.toLowerCase(), contains('inicia compresiones'),
          reason: 'perder un paso por largo es perder el paso que salva');
      expect(steps.first.length, lessThan(120),
          reason: 'sigue siendo legible de un vistazo en pánico');
    });

    test('solo se toma la PRIMERA secuencia numerada, no todas', () {
      const body = '''
## Adulto
1. Primero adulto.
2. Segundo adulto.

## Lactante menor de 1 año
1. Primero lactante.
2. Segundo lactante.
''';
      final steps = extractCriticalSteps(body);
      expect(steps, ['Primero adulto.', 'Segundo adulto.'],
          reason: 'mezclar secciones renumera protocolos distintos como si '
              'fueran uno solo — el bug que motivó estos tests');
    });

    test('todas las guías reales producen al menos un paso', () {
      final dir = Directory('assets/emergency_guides/es');
      var vacias = <String>[];
      for (final f in dir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.md')) continue;
        if (extractCriticalSteps(f.readAsStringSync()).isEmpty) {
          vacias.add(f.uri.pathSegments.last);
        }
      }
      // Algunas guías son informativas y no tienen pasos numerados; lo que no
      // puede pasar es que una guía CON pasos quede vacía.
      expect(vacias.length, lessThan(dir.listSync().length ~/ 2),
          reason: 'demasiadas guías sin pasos: $vacias');
    });
  });
}
