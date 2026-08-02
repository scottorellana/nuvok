// Mantener la pantalla despierta mientras una función crítica lo necesita.
//
// La linterna que alumbra un derrumbe, el SOS Morse que alguien busca desde
// lejos y la baliza que emite tu posición se apagaban solas a los 30 segundos
// del sistema — y el usuario ni se enteraba, porque al desbloquear veía la
// app "encendida" y creía que había estado funcionando.
//
// Contador de razones: varias pantallas pueden pedirlo a la vez (linterna +
// baliza) y la pantalla solo vuelve a dormirse cuando TODAS lo sueltan.
// Cerrar una no puede matar la otra.
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Costura para poder verificar la lógica sin plugin de plataforma.
abstract class AwakeSink {
  Future<void> setAwake(bool value);
}

class _PluginAwake implements AwakeSink {
  @override
  Future<void> setAwake(bool value) =>
      value ? WakelockPlus.enable() : WakelockPlus.disable();
}

class ScreenAwake {
  ScreenAwake._();

  static final Set<String> _reasons = {};
  static AwakeSink _sink = _PluginAwake();

  @visibleForTesting
  static set debugSink(AwakeSink sink) => _sink = sink;

  @visibleForTesting
  static void debugReset() {
    _reasons.clear();
    _sink = _PluginAwake();
  }

  /// Pide mantener la pantalla encendida por [reason]. Idempotente.
  static Future<void> acquire(String reason) async {
    final wasEmpty = _reasons.isEmpty;
    _reasons.add(reason);
    if (wasEmpty) await _apply(true);
  }

  /// Suelta [reason]. La pantalla solo duerme cuando no queda ninguna.
  static Future<void> release(String reason) async {
    if (!_reasons.remove(reason)) return;
    if (_reasons.isEmpty) await _apply(false);
  }

  /// Un fallo del plugin NUNCA debe tumbar la función que lo pidió: es
  /// preferible una linterna que se apague sola a una linterna que no
  /// encienda.
  static Future<void> _apply(bool value) async {
    try {
      await _sink.setAwake(value);
    } catch (_) {}
  }
}
