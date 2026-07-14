import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/core/nuvok_library.dart';
import 'package:nuvok/modules/ai/ai_page.dart';

void main() {
  testWidgets('la pestaña abre con la cuadrícula de los 6 especialistas',
      (tester) async {
    final tmp = await Directory.systemTemp.createTemp('lib');
    NuvokLibrary.setInstanceForTest(tmp);
    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: const AiPage(),
      ),
    ));
    await tester.pumpAndSettle();
    for (final name in ['Vera', 'Elías', 'Bruno', 'Norte', 'Lía', 'Sabio']) {
      expect(find.text(name), findsOneWidget, reason: 'falta tarjeta $name');
    }
  });
}
