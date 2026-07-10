import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_guides.dart';
import 'package:prepper_pad/modules/emergency/survival_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el frontmatter parsea mode y category', () {
    final g = EmergencyGuides.parse('''---
title: Agua en el Bosque
keywords: [agua, bosque]
priority: 2
mode: [bosque, montana]
category: supervivencia
---
# Agua en el Bosque
1. Busca quebradas.
''', id: 'bosque_agua', lang: 'es');
    expect(g, isNotNull);
    expect(g!.modes, ['bosque', 'montana']);
    expect(g.category, 'supervivencia');
  });

  test('guías sin mode/category quedan como emergencia sin modos', () {
    final g = EmergencyGuides.parse('''---
title: RCP
---
# RCP
1. Comprime.
''', id: 'rcp', lang: 'es');
    expect(g!.modes, isEmpty);
    expect(g.category, 'emergencia');
  });

  test('SurvivalMode: 8 entornos con metadatos y persistencia por nombre', () {
    expect(SurvivalMode.values.where((m) => m != SurvivalMode.none).length, 8);
    for (final m in SurvivalMode.values) {
      if (m == SurvivalMode.none) continue;
      expect(m.emoji, isNotEmpty);
      expect(m.nameKey, isNotEmpty);
    }
    expect(survivalModeFromSetting('bosque'), SurvivalMode.bosque);
    expect(survivalModeFromSetting('desierto'), SurvivalMode.desierto);
    expect(survivalModeFromSetting(null), SurvivalMode.none);
    expect(survivalModeFromSetting('inventado'), SurvivalMode.none);
  });

  test('las claves i18n de los 8 modos existen en 7 idiomas', () {
    // Se valida vía coreKeys en locale_service_test; aquí la referencia:
    for (final m in SurvivalMode.values) {
      if (m == SurvivalMode.none) continue;
      expect(m.nameKey.startsWith('mode'), isTrue);
    }
  });
}
