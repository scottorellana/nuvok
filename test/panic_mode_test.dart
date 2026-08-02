import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/emergency_call_button.dart';
import 'package:nuvok/modules/emergency/emergency_page.dart';

/// El modo pánico es lo que ve alguien con las manos temblando y treinta
/// segundos de atención. Lo que no esté en esa pantalla, no existe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Abre la app y entra en modo pánico como lo haría el usuario.
  Future<void> enterPanic(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: EmergencyPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MODO EMERGENCIA').first);
    await tester.pumpAndSettle();
  }

  testWidgets('lo primero de la barra es LLAMAR: marca de verdad, no copia',
      (tester) async {
    await enterPanic(tester);

    // Debe existir un botón que dispare una llamada real (tel:), no un
    // "copiar al portapapeles": si hay señal celular, el 911 salva más que
    // cualquier guía.
    expect(find.byType(EmergencyCallButton), findsOneWidget,
        reason: 'en pánico nadie busca el número: el botón debe marcar');
  });

  testWidgets('hay salida para quien no sabe qué está pasando',
      (tester) async {
    await enterPanic(tester);

    // Seis celdas asumen que el usuario ya diagnosticó. Muchas veces no
    // sabe: necesita el árbol de decisión.
    expect(find.textContaining('NO SÉ'), findsOneWidget,
        reason: 'sin esta celda, quien no sabe qué pasa queda atrapado');
  });

  testWidgets('la hoja de teléfonos marca el número, no lo copia',
      (tester) async {
    final clipboardCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls.add('${(call.arguments as Map)['text']}');
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await enterPanic(tester);
    await tester.tap(find.text('Teléfonos'));
    await tester.pumpAndSettle();

    final tile = find.byType(ListTile).first;
    expect(tile, findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(clipboardCalls, isEmpty,
        reason: 'copiar obliga a abrir el marcador y pegar: eso es tiempo '
            'que el usuario no tiene. Debe marcar directo.');
  });
}
