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

  test('load(zh) trae la guía traducida y completa el resto por fallback',
      () async {
    final zh = await EmergencyGuides.load('zh');
    final agua = zh.where((g) => g.id == 'bosque_agua').firstOrNull;
    expect(agua, isNotNull, reason: 'bosque_agua debe existir en zh');
    expect(agua!.lang, 'zh');
    expect(agua.modes, contains('bosque'));
    // Una guía sin traducción zh llega por fallback (en→es), no desaparece.
    // (rcp_adulto ya se tradujo a zh por AHA 2025; terremoto sigue es/en.)
    final rcp = zh.where((g) => g.id == 'terremoto').firstOrNull;
    expect(rcp, isNotNull);
    expect(['en', 'es'], contains(rcp!.lang));
  });

  test('las claves i18n de los 8 modos existen en 7 idiomas', () {
    // Se valida vía coreKeys en locale_service_test; aquí la referencia:
    for (final m in SurvivalMode.values) {
      if (m == SurvivalMode.none) continue;
      expect(m.nameKey.startsWith('mode'), isTrue);
    }
  });
}
