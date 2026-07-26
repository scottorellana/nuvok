// Política de energía de la radio del mesh: decide CÓMO debe escuchar el
// Bluetooth según la batería y si hay una emergencia en curso.
//
// Motivo: el puente BLE escaneaba siempre a máxima potencia, y en un apagón
// la batería es la vida. La arquitectura de modos + ciclos de escucha está
// inspirada en apps de malla existentes; la implementación es propia.
//
// Lógica pura y sin IO: entra el contexto, sale la decisión. Todo testeable.

enum PowerMode {
  /// Escucha continua. Máxima probabilidad de oír a alguien.
  performance,

  /// Ciclos cortos. El equilibrio por defecto.
  balanced,

  /// Ciclos largos: la radio duerme la mayor parte del tiempo.
  saver,

  /// Mínimo viable para seguir siendo alcanzable con la batería agonizando.
  critical,
}

/// Milisegundos de radio encendida/apagada en cada ciclo.
class DutyCycle {
  const DutyCycle({required this.onMs, required this.offMs});

  final int onMs;

  /// 0 = nunca apaga (escucha continua).
  final int offMs;

  bool get isContinuous => offMs == 0;
}

/// Umbrales de batería (porcentaje).
const int _lowBattery = 20;
const int _criticalBattery = 10;
const int _plentyBattery = 50;

/// Qué modo de energía corresponde al contexto actual.
///
/// REGLA PROPIA DE NUVOK: si hay un SOS activo (propio o de un vecino) se
/// ignora todo ahorro. Un teléfono que cuida la batería y se pierde el
/// rescate no sirve de nada.
///
/// [batteryLevel] en porcentaje, o -1 si aún no se pudo leer: en ese caso NO
/// degradamos la radio (mejor gastar de más que quedar sordos por un dato
/// que falta).
PowerMode resolvePowerMode({
  required int batteryLevel,
  required bool charging,
  bool sosActive = false,
}) {
  if (sosActive) return PowerMode.performance;
  if (charging) return PowerMode.performance;
  if (batteryLevel < 0) return PowerMode.balanced; // desconocida
  if (batteryLevel < _criticalBattery) return PowerMode.critical;
  if (batteryLevel < _lowBattery) return PowerMode.saver;
  if (batteryLevel <= _plentyBattery) return PowerMode.balanced;
  return PowerMode.performance;
}

/// Ciclo de escucha de cada modo. onMs nunca es 0: la radio siempre escucha
/// algo, incluso agonizando.
DutyCycle dutyCycleFor(PowerMode mode) => switch (mode) {
      PowerMode.performance => const DutyCycle(onMs: 1000, offMs: 0),
      PowerMode.balanced => const DutyCycle(onMs: 3000, offMs: 2000),
      PowerMode.saver => const DutyCycle(onMs: 2000, offMs: 8000),
      PowerMode.critical => const DutyCycle(onMs: 1000, offMs: 15000),
    };
