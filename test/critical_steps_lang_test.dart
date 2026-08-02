import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';
import 'package:nuvok/modules/emergency/medical_diagrams.dart';

/// La tarjeta que encabeza cada guía adivinaba el idioma buscando ' Qué ' o
/// ' the ' en el cuerpo. Resultado: una guía japonesa se abría con
/// "PASOS CRÍTICOS" y "NO HAGAS:" en español encima del texto japonés.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCard(WidgetTester tester, EmergencyGuide g) async {
    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: Scaffold(
          body: SingleChildScrollView(
            child: CriticalStepsCard(
              title: g.title,
              body: g.body,
              lang: g.lang,
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  }

  final esperado = {
    'es': 'PASOS CRÍTICOS',
    'en': 'CRITICAL STEPS',
    'pt': 'PASSOS CRÍTICOS',
    'fr': 'ÉTAPES CRITIQUES',
    'zh': '关键步骤',
    'ja': '重要な手順',
    'ht': 'ETAP KRITIK',
  };

  esperado.forEach((lang, cabecera) {
    testWidgets('la guía en $lang se encabeza en $lang', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final guides = await EmergencyGuides.load(lang);
      final rcp = guides.firstWhere((g) => g.id == 'rcp_adulto');
      await pumpCard(tester, rcp);

      expect(find.text(cabecera), findsOneWidget,
          reason: 'quien eligió leer en $lang no debería encontrarse la '
              'cabecera en otro idioma');
    });
  });

  testWidgets('ninguna guía no-española muestra rótulos en español',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final lang in ['pt', 'fr', 'zh', 'ja', 'ht']) {
      final guides = await EmergencyGuides.load(lang);
      await pumpCard(tester, guides.firstWhere((g) => g.id == 'rcp_adulto'));
      expect(find.text('PASOS CRÍTICOS'), findsNothing,
          reason: 'rótulo en español dentro de una guía en $lang');
      expect(find.text('NO HAGAS:'), findsNothing,
          reason: 'contraindicaciones en español dentro de una guía en $lang');
    }
  });
}
