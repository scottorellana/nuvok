// Battery Saver Mode — extends the device's runtime in an emergency by
// turning off the things THIS app actually controls and that actually drain
// the battery. Everything it does is fully reversible: turning the saver off
// restores the exact previous state (screen brightness, mesh radios, the AI
// server), so the user is never left in a mode they can't undo.
//
// It deliberately does NOT pretend to toggle the system WiFi/Bluetooth or the
// OS screen-timeout — a normal app cannot do those on modern Android/macOS,
// so offering switches for them would be fake controls. For those, the page
// shows honest guidance instead.
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../core/nuvok_library.dart';
import '../ai/llama_server.dart';
import '../mesh/mesh_service.dart';
import '../../core/locale_service.dart';

class BatterySaverController extends ChangeNotifier {
  BatterySaverController._();
  static final BatterySaverController instance = BatterySaverController._();

  // Below this the app nudges the user to turn the saver on.
  static const int lowBatteryThreshold = 15;

  bool _enabled = false;
  bool get enabled => _enabled;

  /// True when the battery is known, low and not charging — drives the global
  /// low-battery warning banner.
  bool get isLow =>
      batteryKnown && !isCharging && _batteryLevel <= lowBatteryThreshold;

  // ── User preferences: which measures the saver applies ────────────────
  bool _reduceBrightness = true;
  bool get reduceBrightness => _reduceBrightness;

  bool _pauseMesh = true;
  bool get pauseMesh => _pauseMesh;

  bool _pauseAi = true;
  bool get pauseAi => _pauseAi;

  // ── Remembered prior state, so revert is exact ────────────────────────
  double? _savedBrightness; // brightness before we dimmed it
  bool _meshWasRunning = false; // to restart mesh only if it was on
  String? _aiModelToRestore; // model to reload if we stopped the AI

  // ── Battery stats (real, via battery_plus) ────────────────────────────
  final Battery _battery = Battery();
  int _batteryLevel = -1; // -1 until the first real read completes
  int get batteryLevel => _batteryLevel;
  bool get batteryKnown => _batteryLevel >= 0;

  String _batteryState = 'unknown';
  String get batteryState => _batteryState;
  bool get isCharging => _batteryState == 'charging' || _batteryState == 'full';

  Timer? _ambientMonitor;
  StreamSubscription<BatteryState>? _stateSub;

  /// Reads the battery once, loads saved preferences, and starts listening.
  /// Safe to call from app start; keeps a low-frequency refresh running always
  /// so the global low-battery banner stays accurate.
  Future<void> init() async {
    _loadSettings();
    await _refreshBattery();
    _stateSub ??= _battery.onBatteryStateChanged.listen((s) {
      _batteryState = s.name;
      _refreshBattery();
    });
    _ambientMonitor ??=
        Timer.periodic(const Duration(minutes: 1), (_) => _refreshBattery());
  }

  void _loadSettings() {
    final s = NuvokLibrary.instance.settings['batterySaver'];
    if (s is Map) {
      _reduceBrightness = s['reduceBrightness'] as bool? ?? _reduceBrightness;
      _pauseMesh = s['pauseMesh'] as bool? ?? _pauseMesh;
      _pauseAi = s['pauseAi'] as bool? ?? _pauseAi;
    }
  }

  void _saveSettings() {
    // Fire-and-forget; persistence must never block the UI. Note we persist
    // only the PREFERENCES, never the enabled state — a saver left "on"
    // across restarts could otherwise strand the device dimmed.
    NuvokLibrary.instance.saveSetting('batterySaver', {
      'reduceBrightness': _reduceBrightness,
      'pauseMesh': _pauseMesh,
      'pauseAi': _pauseAi,
    });
  }

  Future<void> _refreshBattery() async {
    try {
      final level = await _battery.batteryLevel;
      _batteryLevel = level;
      try {
        _batteryState = (await _battery.batteryState).name;
      } catch (_) {}
      notifyListeners();
    } catch (_) {
      // Desktop VM or unsupported platform — leave level unknown (-1)
      // rather than lying with a fake number.
    }
  }

  /// Master switch. Turning it on applies every enabled measure; turning it
  /// off reverts ALL of them to exactly how they were before.
  Future<void> toggle() async {
    _enabled = !_enabled;
    notifyListeners(); // reflect the switch immediately
    if (_enabled) {
      await _activate();
    } else {
      await _deactivate();
    }
    notifyListeners();
  }

  Future<void> _activate() async {
    if (_reduceBrightness) await _lowerBrightness();
    if (_pauseMesh) await _stopMesh();
    if (_pauseAi) await _stopAi();
  }

  Future<void> _deactivate() async {
    // Always attempt to revert everything, regardless of current prefs, so a
    // measure that was applied can never be left stuck.
    await _restoreBrightness();
    await _restoreMesh();
    await _restoreAi();
  }

  // ── Brightness ────────────────────────────────────────────────────────
  Future<void> _lowerBrightness() async {
    if (_savedBrightness != null) return; // already dimmed; don't re-save
    try {
      _savedBrightness = await ScreenBrightness().application;
      await ScreenBrightness().setApplicationScreenBrightness(0.25);
    } catch (_) {
      _savedBrightness = null; // platform without brightness control — no-op
    }
  }

  Future<void> _restoreBrightness() async {
    final saved = _savedBrightness;
    _savedBrightness = null;
    try {
      if (saved != null) {
        await ScreenBrightness().setApplicationScreenBrightness(saved);
      } else {
        await ScreenBrightness().resetApplicationScreenBrightness();
      }
    } catch (_) {}
  }

  // ── Mesh radios (WiFi multicast + BLE + WiFi Direct) ──────────────────
  Future<void> _stopMesh() async {
    _meshWasRunning = MeshService.instance.running.value;
    if (_meshWasRunning) {
      try {
        await MeshService.instance.stop();
      } catch (_) {}
    }
  }

  Future<void> _restoreMesh() async {
    if (_meshWasRunning) {
      _meshWasRunning = false;
      try {
        await MeshService.instance.start();
      } catch (_) {}
    }
  }

  // ── Local AI server (llama.cpp) ───────────────────────────────────────
  Future<void> _stopAi() async {
    if (LlamaServer.instance.status == LlamaStatus.running ||
        LlamaServer.instance.status == LlamaStatus.starting) {
      _aiModelToRestore = LlamaServer.instance.modelPath;
      try {
        await LlamaServer.instance.stop();
      } catch (_) {}
    }
  }

  Future<void> _restoreAi() async {
    final model = _aiModelToRestore;
    _aiModelToRestore = null;
    if (model != null) {
      try {
        await LlamaServer.instance.start(model);
      } catch (_) {}
    }
  }

  // ── Preference setters (apply/undo live if the saver is already on) ────
  Future<void> setReduceBrightness(bool v) async {
    _reduceBrightness = v;
    if (_enabled) {
      if (v) {
        await _lowerBrightness();
      } else {
        await _restoreBrightness();
      }
    }
    _saveSettings();
    notifyListeners();
  }

  Future<void> setPauseMesh(bool v) async {
    _pauseMesh = v;
    if (_enabled) {
      if (v) {
        await _stopMesh();
      } else {
        await _restoreMesh();
      }
    }
    _saveSettings();
    notifyListeners();
  }

  Future<void> setPauseAi(bool v) async {
    _pauseAi = v;
    if (_enabled) {
      if (v) {
        await _stopAi();
      } else {
        await _restoreAi();
      }
    }
    _saveSettings();
    notifyListeners();
  }

  @override
  void dispose() {
    _ambientMonitor?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }
}

/// Battery saver settings UI. Has a Scaffold+AppBar (back button), a clear
/// master ON/OFF, only real reversible measures, and honest guidance for the
/// things an app can't toggle itself.
class BatterySaverPage extends StatelessWidget {
  const BatterySaverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'batterySaverTitle')),
        backgroundColor: Colors.green.shade900,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: BatterySaverController.instance,
        builder: (context, _) {
          final ctrl = BatterySaverController.instance;
          return ListView(
            children: [
              // Master status + toggle
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ctrl.enabled
                      ? Colors.green.shade800
                      : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      ctrl.enabled ? Icons.battery_saver : Icons.battery_full,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctrl.enabled ? 'MODO ACTIVO' : 'MODO INACTIVO',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          Text(
                            ctrl.enabled
                                ? 'Toca el interruptor para volver a lo normal'
                                : 'Actívalo para maximizar autonomía',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: ctrl.enabled,
                      onChanged: (_) => ctrl.toggle(),
                      activeThumbColor: Colors.greenAccent,
                    ),
                  ],
                ),
              ),

              // Big explicit revert button while active — impossible to miss.
              if (ctrl.enabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => ctrl.toggle(),
                      icon: const Icon(Icons.restart_alt),
                      label: Text(tr(context, 'deactivateRestore')),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                ),

              // Real battery level.
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      ctrl.isCharging
                          ? Icons.battery_charging_full
                          : Icons.battery_std,
                      color: !ctrl.batteryKnown
                          ? Colors.grey
                          : ctrl.batteryLevel <= 20
                              ? Colors.red
                              : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ctrl.batteryKnown
                          ? 'Batería: ${ctrl.batteryLevel}%'
                              '${ctrl.isCharging ? ' (cargando)' : ''}'
                          : 'Batería: no disponible en este equipo',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),

              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('QUÉ APAGA EL AHORRO',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),

              SwitchListTile(
                secondary: const Icon(Icons.brightness_6),
                title: Text(tr(context, 'lowerBrightness')),
                subtitle: const Text(
                    'La pantalla es el mayor consumo. Se restaura al desactivar.'),
                value: ctrl.reduceBrightness,
                onChanged: (v) => ctrl.setReduceBrightness(v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.cell_tower),
                title: Text(tr(context, 'pauseRadios')),
                subtitle: const Text(
                    'Apaga el mesh (WiFi/Bluetooth de la app). OJO: no '
                    'recibirás SOS de otros mientras esté pausado.'),
                value: ctrl.pauseMesh,
                onChanged: (v) => ctrl.setPauseMesh(v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.psychology),
                title: Text(tr(context, 'pauseAi')),
                subtitle: const Text(
                    'Detiene el modelo local (gran consumo). Se reinicia al '
                    'desactivar el ahorro si estaba activo.'),
                value: ctrl.pauseAi,
                onChanged: (v) => ctrl.setPauseAi(v),
              ),

              const SizedBox(height: 16),

              // Honest guidance for what the app can't toggle itself.
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('Para ahorrar aún más (desde ajustes del sistema)',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _tip('Activa el modo avión si no necesitas señal'),
                    _tip('Reduce el tiempo de apagado de pantalla'),
                    _tip('Cierra otras apps en segundo plano'),
                    _tip('Usa la linterna solo cuando sea necesario'),
                    _tip('Desactiva el GPS cuando no lo uses'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
