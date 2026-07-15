import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/core/nuvok_library.dart';
import 'package:nuvok/modules/ai/ai_page.dart';

void main() {
  testWidgets('la pestaña abre con la cuadrícula de los 6 especialistas',
      (tester) async {
    // Sync: el IO real async nunca completa bajo el reloj falso de
    // testWidgets (el await se cuelga hasta el timeout de 10 minutos).
    final tmp = Directory.systemTemp.createTempSync('lib');
    NuvokLibrary.setInstanceForTest(tmp);
    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: const AiPage(),
      ),
    ));
    // Frames fijos (no pumpAndSettle): la cuadrícula tiene trabajo async que
    // nunca "asienta" bajo el reloj falso del test — mismo patrón que
    // responsive_ux_matrix_test.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final name in ['Vera', 'Elías', 'Bruno', 'Norte', 'Lía', 'Sabio']) {
      expect(find.text(name), findsOneWidget, reason: 'falta tarjeta $name');
    }
  });
}
