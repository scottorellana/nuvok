import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';
import 'package:nuvok/modules/emergency/emergency_page.dart';

// En un iPhone la columna de bloques fijos (CTA, buscador, botones, directorio)
// consumía casi toda la altura y solo el grid interior scrolleaba, aplastado
// en una franja mínima. La página entera debe deslizar como un solo scroll.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iPhone: toda la página desliza y la última guía es alcanzable',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final guides = await EmergencyGuides.load('es');
    final lastTitle = EmergencyGuides.search(guides, '').last.title;

    await tester.pumpWidget(const MaterialApp(home: EmergencyPage()));
    await tester.pumpAndSettle();

    expect(find.text('MODO EMERGENCIA'), findsOneWidget);

    // Deslizar hacia arriba repetidamente sobre la zona del encabezado.
    for (var i = 0; i < 45; i++) {
      await tester.dragFrom(const Offset(195, 500), const Offset(0, -500));
      await tester.pumpAndSettle();
    }

    // El encabezado debe haberse desplazado fuera de pantalla…
    expect(find.text('MODO EMERGENCIA').hitTestable(), findsNothing,
        reason: 'el encabezado debe scrollear junto con las guías');
    // …y la última guía del grid debe estar a la vista.
    expect(find.text(lastTitle), findsOneWidget,
        reason: 'deslizando se debe llegar hasta la última guía');
  });

  testWidgets('iPhone SE: la página carga sin overflow', (tester) async {
    tester.view.physicalSize = const Size(375 * 2, 667 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: EmergencyPage()));
    await tester.pumpAndSettle();

    expect(find.byType(EmergencyPage), findsOneWidget);
  });
}
