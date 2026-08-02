import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/power_policy.dart';

void main() {
  _advertisePlanTests();
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

/// El ANUNCIO (advertising) es la otra mitad de la radio y se le había
/// olvidado la política: en Android estaba clavado en ADVERTISE_MODE_LOW_LATENCY
/// con potencia media, sin importar si la batería estaba al 5% o si había un
/// SOS en curso. Dos errores en direcciones opuestas: fundía la batería
/// agonizando, y anunciaba flojo justo cuando alguien pedía auxilio.
void _advertisePlanTests() {
  group('plan de anuncio BLE', () {
    test('con la batería agonizando el anuncio también se frena', () {
      final p = advertisePlanFor(PowerMode.critical, sosActive: false);
      expect(p.mode, AdvertiseRate.lowPower,
          reason: 'anunciar cada 100ms al 5% de batería la funde');
      expect(p.txPower, AdvertiseTxPower.low);
    });

    test('en ahorro baja, sin llegar al mínimo del modo crítico', () {
      final p = advertisePlanFor(PowerMode.saver, sosActive: false);
      expect(p.mode, AdvertiseRate.lowPower);
    });

    test('el equilibrio por defecto no va a máxima frecuencia', () {
      final p = advertisePlanFor(PowerMode.balanced, sosActive: false);
      expect(p.mode, AdvertiseRate.balanced);
    });

    test('con SOS activo manda el alcance, no la batería', () {
      for (final m in PowerMode.values) {
        final p = advertisePlanFor(m, sosActive: true);
        expect(p.mode, AdvertiseRate.lowLatency,
            reason: 'quien pide auxilio quiere que lo encuentren YA ($m)');
        expect(p.txPower, AdvertiseTxPower.high,
            reason: 'potencia media recorta el alcance justo cuando importa');
      }
    });

    test('el plan viaja al canal como texto estable', () {
      // Kotlin/Swift traducen estas cadenas: si cambian, el nativo deja de
      // entenderlas en silencio y vuelve al valor por defecto.
      expect(advertisePlanFor(PowerMode.critical, sosActive: false).modeName,
          'lowPower');
      expect(advertisePlanFor(PowerMode.balanced, sosActive: false).modeName,
          'balanced');
      expect(advertisePlanFor(PowerMode.balanced, sosActive: true).modeName,
          'lowLatency');
      expect(advertisePlanFor(PowerMode.balanced, sosActive: true).txPowerName,
          'high');
    });
  });
}
