import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';

// Las guías embebidas deben cargar, indexarse y encontrarse por síntoma.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cargan las guías es y en, con la misma cantidad', () async {
    final es = await EmergencyGuides.load('es');
    final en = await EmergencyGuides.load('en');
    expect(es.length, greaterThanOrEqualTo(16));
    expect(en.length, es.length,
        reason: 'cada guía es debe tener su gemela en inglés');
    // Frontmatter parseado: nada quedó con el id como título.
    for (final g in [...es, ...en]) {
      expect(g.title, isNot(g.id));
      expect(g.keywords, isNotEmpty, reason: '${g.id} sin keywords');
      expect(g.body, contains('##'), reason: '${g.id} sin secciones');
      expect(g.body.toLowerCase(), isNot(contains('bls')),
          reason: 'sin marcas registradas');
    }
    // Ordenadas por prioridad: lo vital primero.
    expect(es.first.priority, 1);
  });

  test('búsqueda por síntoma encuentra la guía correcta', () async {
    final es = await EmergencyGuides.load('es');
    expect(EmergencyGuides.search(es, 'no respira').first.id,
        anyOf(startsWith('rcp'), 'atragantamiento'));
    expect(
        EmergencyGuides.search(es, 'sangrado').first.id, 'hemorragia_severa');
    // "se ahoga" debe encontrar atragantamiento O rcp (ambos tienen keywords relevantes)
    expect(EmergencyGuides.search(es, 'se ahoga').first.id,
        anyOf('atragantamiento', 'rcp_adulto', 'rcp_nino_bebe'));
    expect(
        EmergencyGuides.search(es, 'culebra').first.id, 'mordeduras_picaduras');
    expect(EmergencyGuides.search(es, 'corazón').first.id,
        anyOf('infarto_acv', 'rcp_adulto'));
    // Sin acentos también funciona.
    expect(EmergencyGuides.search(es, 'corazon'), isNotEmpty);
    // Guía de agua supervivencia es encontrable
    expect(EmergencyGuides.search(es, 'agua').first.id,
        anyOf('agua_survival', 'inundacion'));
    // Guía de señales de rescate es encontrable
    expect(EmergencyGuides.search(es, 'rescate').first.id, 'senas_rescate');
    // Vacía → todas por prioridad.
    expect(EmergencyGuides.search(es, '').length, es.length);
  });

  test('búsqueda en inglés', () async {
    final en = await EmergencyGuides.load('en');
    expect(EmergencyGuides.search(en, 'not breathing').first.id,
        startsWith('rcp'));
    expect(
        EmergencyGuides.search(en, 'snake').first.id, 'mordeduras_picaduras');
  });
}
