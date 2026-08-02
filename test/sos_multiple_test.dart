import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/emergency/sos_alarm.dart';

/// Un terremoto no manda un SOS: manda varios a la vez. Si el segundo borra
/// al primero, el vecino que escribió "estoy bajo el escombro del garaje"
/// desaparece de la pantalla sin que nadie lo haya leído.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ctrl = SosAlarmController.instance;
  tearDown(ctrl.silenceAll);

  test('dos SOS de personas distintas conviven, no se pisan', () {
    ctrl.trigger(id: 'p1', fromName: 'Ana', note: 'bajo el escombro del garaje');
    ctrl.trigger(id: 'p2', fromName: 'Beto', note: 'pierna atrapada');

    expect(ctrl.alerts, hasLength(2),
        reason: 'el segundo SOS no puede borrar al primero');
    expect(ctrl.alerts.map((a) => a.fromName), containsAll(['Ana', 'Beto']));
    expect(ctrl.alerts.first.note, contains('garaje'),
        reason: 'la nota es lo que dice dónde buscar: no se puede perder');
  });

  test('el mismo peer repitiendo su SOS actualiza, no duplica', () {
    ctrl.trigger(id: 'p1', fromName: 'Ana', note: 'atrapada');
    ctrl.trigger(id: 'p1', fromName: 'Ana', note: 'atrapada, se inunda');

    expect(ctrl.alerts, hasLength(1));
    expect(ctrl.alerts.single.note, 'atrapada, se inunda',
        reason: 'la nota más reciente es la que vale');
  });

  test('cancelar el SOS de uno no calla el del otro', () {
    ctrl.trigger(id: 'p1', fromName: 'Ana');
    ctrl.trigger(id: 'p2', fromName: 'Beto');

    ctrl.dismiss('p1');

    expect(ctrl.alarming, isTrue,
        reason: 'Beto sigue pidiendo auxilio: la alarma no se puede callar');
    expect(ctrl.alerts.single.fromName, 'Beto');

    ctrl.dismiss('p2');
    expect(ctrl.alarming, isFalse, reason: 'sin nadie pidiendo, la alarma para');
  });

  test('dos peers con el mismo nombre no se confunden', () {
    // "José" es un nombre común; el id del remitente es lo único único.
    ctrl.trigger(id: 'p1', fromName: 'José', note: 'primer piso');
    ctrl.trigger(id: 'p2', fromName: 'José', note: 'azotea');

    expect(ctrl.alerts, hasLength(2),
        reason: 'deduplicar por nombre borraría a una persona real');
    ctrl.dismiss('p1');
    expect(ctrl.alerts.single.note, 'azotea');
  });

  testWidgets('la pantalla muestra a TODOS los que piden auxilio',
      (tester) async {
    ctrl.trigger(id: 'p1', fromName: 'Ana', note: 'bajo el garaje');
    ctrl.trigger(id: 'p2', fromName: 'Beto', note: 'pierna atrapada');

    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: const SosAlarmOverlay(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    for (final quien in ['Ana', 'Beto', 'bajo el garaje', 'pierna atrapada']) {
      expect(find.textContaining(quien), findsWidgets,
          reason: 'no aparece "$quien": esa persona queda invisible');
    }

    // Atender a Ana no puede borrar a Beto de la pantalla.
    await tester.tap(find.text('ENTENDIDO').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Beto'), findsWidgets);
    expect(find.textContaining('Ana'), findsNothing);

    ctrl.silenceAll(); // soltar el temporizador de escalación
    await tester.pump(const Duration(milliseconds: 100));
  });
}
