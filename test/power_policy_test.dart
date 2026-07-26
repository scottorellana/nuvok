import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/power_policy.dart';

void main() {
  group('resolvePowerMode — franjas de batería', () {
    test('cargando o batería alta → rendimiento (escucha continua)', () {
      expect(resolvePowerMode(batteryLevel: 80, charging: false),
          PowerMode.performance);
      expect(resolvePowerMode(batteryLevel: 15, charging: true),
          PowerMode.performance,
          reason: 'enchufado no hay razón para ahorrar');
    });

    test('batería media → equilibrado', () {
      expect(resolvePowerMode(batteryLevel: 45, charging: false),
          PowerMode.balanced);
      expect(resolvePowerMode(batteryLevel: 21, charging: false),
          PowerMode.balanced);
    });

    test('batería baja → ahorro', () {
      expect(
          resolvePowerMode(batteryLevel: 15, charging: false), PowerMode.saver);
    });

    test('batería crítica → crítico', () {
      expect(resolvePowerMode(batteryLevel: 5, charging: false),
          PowerMode.critical);
    });

    test('batería desconocida (-1) → equilibrado, nunca crítico', () {
      expect(resolvePowerMode(batteryLevel: -1, charging: false),
          PowerMode.balanced,
          reason: 'sin dato de batería no debemos degradar la radio');
    });
  });

  group('REGLA NUVOK: un SOS activo anula el ahorro', () {
    test('SOS con batería crítica sigue en rendimiento máximo', () {
      expect(
        resolvePowerMode(batteryLevel: 3, charging: false, sosActive: true),
        PowerMode.performance,
        reason: 'perderse el rescate por ahorrar batería es inaceptable',
      );
    });

    test('sin SOS, la misma batería sí ahorra', () {
      expect(resolvePowerMode(batteryLevel: 3, charging: false),
          PowerMode.critical);
    });
  });

  group('ciclos de escucha', () {
    test('rendimiento es continuo (sin apagado)', () {
      final d = dutyCycleFor(PowerMode.performance);
      expect(d.offMs, 0, reason: 'continuo = nunca apaga la radio');
      expect(d.onMs, greaterThan(0));
    });

    test('los modos de ahorro apagan cada vez más', () {
      final b = dutyCycleFor(PowerMode.balanced);
      final s = dutyCycleFor(PowerMode.saver);
      final c = dutyCycleFor(PowerMode.critical);
      expect(b.offMs, greaterThan(0));
      expect(s.offMs, greaterThan(b.offMs));
      expect(c.offMs, greaterThan(s.offMs));
    });

    test('siempre escucha algo: onMs nunca es 0', () {
      for (final m in PowerMode.values) {
        expect(dutyCycleFor(m).onMs, greaterThan(0),
            reason: '$m dejaría la radio sorda');
      }
    });
  });
}
