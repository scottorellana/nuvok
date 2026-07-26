// Aplica la política de energía a la radio del mesh y controla el servicio
// de segundo plano de Android.
//
// Escucha la batería (BatterySaverController) y el estado de SOS
// (MeshService) y empuja el modo resultante al puente nativo. Toda la lógica
// de decisión vive en power_policy.dart (pura y testeada); esto es solo el
// cableado con las plataformas.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../tools/battery_saver.dart';
import 'power_policy.dart';

class MeshPowerController {
  MeshPowerController._();
  static final MeshPowerController instance = MeshPowerController._();

  static const _ble = MethodChannel('nuvok/ble_mesh');
  static const _background = MethodChannel('nuvok/mesh_background');

  PowerMode? _applied;
  bool _sosActive = false;
  bool _wired = false;

  /// Empieza a seguir la batería para ajustar la radio. Idempotente.
  void start() {
    if (_wired) return;
    _wired = true;
    BatterySaverController.instance.addListener(_reevaluate);
    _reevaluate();
  }

  /// Un SOS (propio o de un vecino) anula el ahorro: la radio va a máxima
  /// potencia mientras dure.
  void setSosActive(bool active) {
    if (active) _incomingSosTimer?.cancel();
    if (_sosActive == active) return;
    _sosActive = active;
    _reevaluate();
  }

  /// Cuánto mantenemos la radio a tope tras oír el SOS de un vecino. Acotado
  /// a propósito: sin caducidad, un SOS ajeno dejaría el teléfono quemando
  /// batería para siempre — justo lo contrario de lo que necesita quien
  /// podría tener que ayudar.
  static const incomingSosBoost = Duration(minutes: 10);

  Timer? _incomingSosTimer;

  /// El SOS de un vecino también sube la radio a máxima potencia: para
  /// ayudarle hay que poder oírle y reenviar su mensaje.
  void boostForIncomingSos() {
    _incomingSosTimer?.cancel();
    _sosActive = true;
    _reevaluate();
    _incomingSosTimer = Timer(incomingSosBoost, () {
      _sosActive = false;
      _reevaluate();
    });
  }

  void _reevaluate() {
    final saver = BatterySaverController.instance;
    final mode = resolvePowerMode(
      batteryLevel: saver.batteryLevel,
      charging: saver.isCharging,
      sosActive: _sosActive,
    );
    if (mode == _applied) return;
    _applied = mode;
    final duty = dutyCycleFor(mode);
    _push(mode, duty);
  }

  Future<void> _push(PowerMode mode, DutyCycle duty) async {
    try {
      await _ble.invokeMethod<bool>('setPowerMode', {
        'mode': mode.name,
        'onMs': duty.onMs,
        'offMs': duty.offMs,
      });
    } on MissingPluginException {
      // Plataforma sin puente BLE (tests, escritorio): la malla sigue por LAN.
    } catch (e) {
      if (kDebugMode) debugPrint('setPowerMode falló: $e');
    }
  }

  // ---- Servicio en segundo plano (solo Android) ----

  /// ¿El usuario quiere que la malla siga viva con la app cerrada?
  /// En iOS siempre false: Apple no permite servicios permanentes (allí el
  /// equivalente es la restauración de estado BLE, que es automática).
  Future<bool> backgroundEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _background.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBackgroundEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _background
          .invokeMethod<bool>('setEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  /// Al arrancar la malla: levanta el servicio si el usuario lo dejó activo.
  Future<void> startBackgroundIfEnabled() async {
    if (!Platform.isAndroid) return;
    try {
      await _background.invokeMethod<bool>('startIfEnabled');
    } catch (_) {}
  }
}
