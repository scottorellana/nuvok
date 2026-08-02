import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/emergency/emergency_page.dart';

/// El modo pánico son seis botones gigantes que alguien toca con las manos
/// temblando. Estaban en un ternario es/en: con la app en japonés, chino,
/// francés, portugués o criollo, todos salían en INGLÉS.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const claves = [
    'panicTitle',
    'panicNotBreathing',
    'panicChoking',
    'panicBleeding',
    'panicBurn',
    'panicFracture',
    'panicHeart',
    'panicUnknown',
    'panicBarCpr',
    'panicBarLight',
    'panicBarPhones',
    'panicBarMap',
    'emergencyModeCta',
    'sosDialogTitle',
    'sosDialogConfirm',
    'sosActivated',
  ];

  test('los rótulos del pánico existen en los 7 idiomas', () {
    for (final k in claves) {
      for (final lang in AppLanguage.values) {
        final s = AppStrings(lang).t(k);
        expect(s, isNotEmpty, reason: '$k falta en ${lang.code}');
        expect(s, isNot(k), reason: '$k sin traducir en ${lang.code}');
      }
    }
  });

  test('ningún idioma cae al inglés por descuido', () {
    // Si una clave quedó idéntica al inglés en un idioma que no lo comparte,
    // es que nadie la tradujo. Se permite donde de verdad coincide (siglas
    // internacionales como CPR/SOS, o palabras iguales entre lenguas latinas).
    const compartidasLegitimas = {
      'panicBarCpr',
      'sosDialogTitle',
      'sosDialogConfirm',
      'sosActivated',
    };
    final sospechosas = <String>[];
    for (final k in claves) {
      if (compartidasLegitimas.contains(k)) continue;
      final en = AppStrings(AppLanguage.en).t(k);
      for (final lang in [AppLanguage.zh, AppLanguage.ja, AppLanguage.ht]) {
        if (AppStrings(lang).t(k) == en) sospechosas.add('$k.${lang.code}');
      }
    }
    expect(sospechosas, isEmpty,
        reason: 'rótulos que se quedaron en inglés: $sospechosas');
  });

  testWidgets('en japonés los botones gigantes NO salen en inglés',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    LocaleService.instance.setLanguage(AppLanguage.ja);
    addTearDown(() => LocaleService.instance.setLanguage(AppLanguage.es));

    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: const EmergencyPage(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(
        find.text(AppStrings(AppLanguage.ja).t('emergencyModeCta')).first);
    await tester.pumpAndSettle();

    // Confirmar que de verdad entramos en el modo pánico: si no, los expects
    // de "no hay inglés" pasarían trivialmente sin probar nada.
    expect(find.text(AppStrings(AppLanguage.ja).t('panicTitle')), findsOneWidget,
        reason: 'no se abrió el modo pánico');

    for (final ingles in [
      'NOT BREATHING\n(CPR)',
      'CHOKING',
      'SEVERE\nBLEEDING',
      'BURN',
      "I DON'T KNOW\nWHAT'S WRONG",
    ]) {
      expect(find.text(ingles), findsNothing,
          reason: 'botón en inglés con la app en japonés: "$ingles"');
    }
    // Y sí está el japonés.
    expect(find.text(AppStrings(AppLanguage.ja).t('panicChoking')),
        findsOneWidget);
  });
}
