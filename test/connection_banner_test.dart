import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/connection_banner.dart';
import 'package:prepper_pad/modules/mesh/transport_health.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('con pares muestra estado verde con el conteo y el transporte',
      (tester) async {
    await tester.pumpWidget(_wrap(const ConnectionBanner(
      healths: [
        TransportHealth(
            name: 'ble', state: TransportState.connected, peers: 2),
        TransportHealth(
            name: 'lan', state: TransportState.connected, peers: 1),
      ],
      searching: Duration.zero,
    )));
    expect(find.textContaining('3'), findsOneWidget);
    expect(find.textContaining('Bluetooth'), findsOneWidget);
  });

  testWidgets('sin pares muestra búsqueda y abre el asistente al tocar',
      (tester) async {
    await tester.pumpWidget(_wrap(const ConnectionBanner(
      healths: [
        TransportHealth(name: 'ble', state: TransportState.off),
      ],
      searching: Duration(seconds: 60),
    )));
    expect(find.textContaining('Buscando'), findsOneWidget);
    await tester.tap(find.byType(ConnectionBanner));
    await tester.pumpAndSettle();
    // La hoja del asistente lista el paso de Bluetooth apagado primero.
    expect(find.text('Asistente de conexión'), findsOneWidget);
    expect(find.textContaining('Enciende Bluetooth'), findsWidgets);
  });
}
