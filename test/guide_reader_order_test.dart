import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/emergency_page.dart';
import 'package:nuvok/modules/emergency/medical_diagrams.dart';

/// Quien abre una guía en una emergencia real lee lo primero que ve y actúa.
/// Si lo primero es una foto de 300px, los pasos que salvan quedan bajo el
/// pliegue y hay que scrollear con una mano ocupada.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('los pasos que salvan van antes que la foto', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: EmergencyPage()));
    await tester.pumpAndSettle();
    // Entrar por el modo pánico: es el camino más corto a una guía con foto.
    await tester.tap(find.text('MODO EMERGENCIA').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('NO RESPIRA\n(RCP)'));
    // La guía de RCP trae la animación de compresiones, que nunca "settlea":
    // pumps acotados en vez de pumpAndSettle.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    final steps = find.byType(CriticalStepsCard);
    expect(steps, findsOneWidget, reason: 'la guía debe traer pasos');

    final images = find.byType(Image);
    if (images.evaluate().isEmpty) return; // guía sin foto: nada que ordenar

    final stepsY = tester.getTopLeft(steps).dy;
    final photoY = tester.getTopLeft(images.first).dy;
    expect(stepsY, lessThan(photoY),
        reason: 'la foto empuja los pasos bajo el pliegue: primero qué hacer, '
            'después cómo se ve');
  });
}
