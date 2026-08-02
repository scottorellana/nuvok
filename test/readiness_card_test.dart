import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/prep/checklist_page.dart';
import 'package:nuvok/modules/prep/readiness_card.dart';

/// La tarjeta solo sirve si dice QUÉ se pierde, no "falta X". Quien la lee
/// tiene que entender qué no va a poder hacer el día del apagón.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('en un equipo vacío nombra lo que se pierde, no lo que falta',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: const Scaffold(body: ReadinessCard()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // Sin biblioteca/modelos/mapas instalados (entorno de test), la tarjeta
    // tiene que estar diciendo algo útil.
    expect(find.byType(ReadinessCard), findsOneWidget);
    final textos = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(textos, contains('%'), reason: 'sin marcador no se ve el avance');
    expect(
      textos.contains('no sabrás') ||
          textos.contains('no responden') ||
          textos.contains('nadie puede encontrarte') ||
          textos.contains('listo'),
      isTrue,
      reason: 'la tarjeta debe explicar la consecuencia, no listar carencias: '
          'lo que dice "$textos"',
    );
  });

  testWidgets('la pantalla de preparación la incluye', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: const ChecklistPage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ReadinessCard), findsOneWidget,
        reason: 'de nada sirve tener agua para tres días si el día del apagón '
            'descubres que nunca descargaste los mapas');
  });
}
