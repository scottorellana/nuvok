import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/tools/battery_policy.dart';

/// En un apagón el teléfono es el único recurso y debe durar días. El ahorro
/// existía pero solo se activaba si el usuario lo encontraba y lo tocaba:
/// alguien con 6% de batería, a oscuras y asustado, no va a navegar menús.
///
/// Estas reglas deciden cuándo la app actúa sola. Son puras para poder
/// verificarlas sin batería real.
void main() {
  group('cuándo activar el ahorro por sí solo', () {
    test('batería crítica y sin cargador → se activa', () {
      expect(
          shouldAutoEnableSaver(
              level: 8, charging: false, alreadyOn: false, userTurnedOff: false),
          isTrue);
    });

    test('en el umbral exacto ya actúa', () {
      expect(
          shouldAutoEnableSaver(
              level: autoSaverThreshold,
              charging: false,
              alreadyOn: false,
              userTurnedOff: false),
          isTrue);
      expect(
          shouldAutoEnableSaver(
              level: autoSaverThreshold + 1,
              charging: false,
              alreadyOn: false,
              userTurnedOff: false),
          isFalse);
    });

    test('cargando NO se activa: la batería está subiendo', () {
      expect(
          shouldAutoEnableSaver(
              level: 5, charging: true, alreadyOn: false, userTurnedOff: false),
          isFalse);
    });

    test('si el usuario lo apagó a mano, se respeta su decisión', () {
      // Reactivarlo a la fuerza sería pelearse con la persona justo cuando
      // más necesita controlar su equipo.
      expect(
          shouldAutoEnableSaver(
              level: 5, charging: false, alreadyOn: false, userTurnedOff: true),
          isFalse);
    });

    test('ya encendido: no se reactiva en bucle', () {
      expect(
          shouldAutoEnableSaver(
              level: 5, charging: false, alreadyOn: true, userTurnedOff: false),
          isFalse);
    });

    test('batería desconocida (-1) no dispara nada', () {
      expect(
          shouldAutoEnableSaver(
              level: -1, charging: false, alreadyOn: false, userTurnedOff: false),
          isFalse,
          reason: 'un escritorio sin batería no debe entrar en ahorro');
    });
  });

  group('la malla mínima mantiene lo vital', () {
    test('bajo el umbral crítico la malla NO se apaga entera', () {
      // Apagar la malla ahorra batería pero deja de recibir el SOS del
      // vecino: exactamente el caso para el que existe la app.
      expect(meshPlanFor(level: 5, charging: false), MeshPowerPlan.minimal);
    });

    test('batería baja pero no crítica: malla equilibrada', () {
      expect(meshPlanFor(level: 25, charging: false), MeshPowerPlan.balanced);
    });

    test('con cargador, sin recortes', () {
      expect(meshPlanFor(level: 5, charging: true), MeshPowerPlan.full);
    });

    test('batería sana: sin recortes', () {
      expect(meshPlanFor(level: 80, charging: false), MeshPowerPlan.full);
    });
  });
}
