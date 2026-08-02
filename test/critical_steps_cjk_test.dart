import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';
import 'package:nuvok/modules/emergency/medical_diagrams.dart';

/// Los filtros de longitud se escribieron mirando español e inglés, donde una
/// instrucción son 15-40 caracteres y lo que mide 3 es basura de formato. En
/// chino y japonés una instrucción CLÍNICA COMPLETA cabe en 2-3 caracteres:
/// 冷却 (enfriar), 覆盖 (cubrir). El mismo filtro que limpia basura latina
/// borra pasos que salvan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un paso chino corto NO se descarta por corto', () {
    const body = '''
## Pasos

1. 冷却
2. 覆盖
3. 就医
''';
    final steps = extractCriticalSteps(body);
    expect(steps, hasLength(3),
        reason: 'en chino una instrucción completa cabe en 2 caracteres: '
            'medir con el listón del español borra pasos clínicos enteros');
    expect(steps, contains('覆盖'));
  });

  test('la basura de formato latina se sigue descartando', () {
    const body = '''
1. a
2. Cubre la quemadura con un paño limpio
''';
    final steps = extractCriticalSteps(body);
    expect(steps, hasLength(1), reason: '"a" no es una instrucción');
  });

  group('paridad entre idiomas sobre los assets reales', () {
    // Si la misma guía rinde menos pasos en un idioma que en los demás, a
    // alguien le falta una instrucción en su idioma.
    const langs = ['es', 'en', 'pt', 'fr', 'zh', 'ja', 'ht'];

    test('ninguna guía pierde pasos en un idioma concreto', () async {
      final porIdioma = <String, List<EmergencyGuide>>{};
      for (final l in langs) {
        porIdioma[l] = await EmergencyGuides.load(l);
      }

      final quejas = <String>[];
      for (final base in porIdioma['es']!) {
        final cuentas = <String, int>{};
        for (final l in langs) {
          final g = porIdioma[l]!.where((g) => g.id == base.id).firstOrNull;
          if (g == null) continue;
          cuentas[l] = extractCriticalSteps(g.body).length;
        }
        if (cuentas.length < 2) continue;
        final maxi = cuentas.values.reduce((a, b) => a > b ? a : b);
        if (maxi == 0) continue;
        for (final e in cuentas.entries) {
          // Un paso menos es un paso que alguien no va a leer.
          if (e.value < maxi) {
            quejas.add('${base.id}: ${e.key}=${e.value} vs max=$maxi');
          }
        }
      }
      expect(quejas, isEmpty,
          reason: 'guías con menos pasos en un idioma que en otro:\n'
              '${quejas.take(25).join('\n')}');
    });
  });
}
