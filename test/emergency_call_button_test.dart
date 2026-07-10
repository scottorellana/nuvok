import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_call_button.dart';

void main() {
  testWidgets('muestra el número del país detectado', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: EmergencyCallButton(countryOverride: 'HN')),
    ));
    expect(find.textContaining('911'), findsOneWidget);
    expect(find.byIcon(Icons.phone), findsOneWidget);
  });

  testWidgets('país europeo muestra 112', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: EmergencyCallButton(countryOverride: 'ES')),
    ));
    expect(find.textContaining('112'), findsOneWidget);
  });
}
