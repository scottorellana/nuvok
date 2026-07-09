import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/connection_banner.dart';
import 'package:prepper_pad/modules/mesh/transport_health.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('con pares muestra estado verde con el conteo ÚNICO',
      (tester) async {
    // El mismo par oído por BLE y LAN: peers por transporte suman 3, pero
    // los pares únicos (peerCount) son 2 — el banner debe decir 2.
    await tester.pumpWidget(_wrap(ConnectionBanner(
      healths: const [
        TransportHealth(
            name: 'ble', state: TransportState.connected, peers: 2),
        TransportHealth(
            name: 'lan', state: TransportState.connected, peers: 1),
      ],
      totalPeers: 2,
      searchStart: DateTime.now(),
    )));
    expect(find.textContaining('2'), findsOneWidget);
    expect(find.textContaining('3'), findsNothing);
    expect(find.textContaining('Bluetooth'), findsOneWidget);
  });

  testWidgets('sin pares muestra búsqueda y abre el asistente al tocar',
      (tester) async {
    await tester.pumpWidget(_wrap(ConnectionBanner(
      healths: const [
        TransportHealth(name: 'ble', state: TransportState.off),
      ],
      totalPeers: 0,
      searchStart: DateTime.now().subtract(const Duration(seconds: 60)),
    )));
    expect(find.textContaining('Buscando'), findsOneWidget);
    await tester.tap(find.byType(ConnectionBanner));
    await tester.pumpAndSettle();
    // La hoja del asistente lista el paso de Bluetooth apagado primero, y
    // como la búsqueda lleva 60s (calculada AL TOCAR, no al construir),
    // también propone el hotspot.
    expect(find.text('Asistente de conexión'), findsOneWidget);
    expect(find.textContaining('Enciende Bluetooth'), findsWidgets);
    expect(find.textContaining('hotspot'), findsWidgets);
  });
}
