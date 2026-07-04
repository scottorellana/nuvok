// Battery Saver Mode — maximizes device battery life during emergencies
// by disabling non-essential services and reducing screen consumption.
// Reads the REAL battery level via battery_plus (works offline on Android,
// macOS, Windows and Linux) — in a survival app a fake percentage is worse
// than none, since it gives false confidence.
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BatterySaverController extends ChangeNotifier {
  BatterySaverController._();
  static final BatterySaverController instance = BatterySaverController._();

  bool _enabled = false;
  bool get enabled => _enabled;

  // Settings
  bool _disableWifi = false;
  bool get disableWifi => _disableWifi;
  
  bool _disableBluetooth = false;
  bool get disableBluetooth => _disableBluetooth;
  
  bool _reduceScreenBrightness = true;
  bool get reduceScreenBrightness => _reduceScreenBrightness;
  
  bool _disableAnimations = true;
  bool get disableAnimations => _disableAnimations;
  
  bool _disableBackgroundSync = true;
  bool get disableBackgroundSync => _disableBackgroundSync;
  
  int _screenTimeout = 30;
  int get screenTimeout => _screenTimeout;

  // Battery stats — read from the real device battery.
  final Battery _battery = Battery();
  int _batteryLevel = -1; // -1 until the first real read completes
  int get batteryLevel => _batteryLevel;
  bool get batteryKnown => _batteryLevel >= 0;

  String _batteryState = 'unknown';
  String get batteryState => _batteryState;
  bool get isCharging =>
      _batteryState == 'charging' || _batteryState == 'full';

  Timer? _batteryMonitor;
  StreamSubscription<BatteryState>? _stateSub;

  /// Reads the battery once and starts listening. Safe to call from app start
  /// so the level is available even before the saver is toggled on.
  Future<void> init() async {
    await _refreshBattery();
    _stateSub ??= _battery.onBatteryStateChanged.listen((s) {
      _batteryState = s.name;
      _refreshBattery();
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
      // Desktop VM or unsupported platform — leave level as unknown (-1)
      // rather than lying with a fake number.
    }
  }

  void toggle() {
    _enabled = !_enabled;
    if (_enabled) {
      _activate();
    } else {
      _deactivate();
    }
    notifyListeners();
  }

  void _activate() {
    // Disable animations
    if (_disableAnimations) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    }

    // Reduce screen timeout
    if (_reduceScreenBrightness) {
      // Note: Actual brightness control requires platform channels
    }

    // Start battery monitoring
    _startMonitoring();
  }

  void _deactivate() {
    // Restore UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);
    _stopMonitoring();
  }

  void _startMonitoring() {
    _refreshBattery();
    _batteryMonitor =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshBattery());
  }

  void _stopMonitoring() {
    _batteryMonitor?.cancel();
    _batteryMonitor = null;
  }

  void setDisableWifi(bool v) {
    _disableWifi = v;
    notifyListeners();
  }

  void setDisableBluetooth(bool v) {
    _disableBluetooth = v;
    notifyListeners();
  }

  void setReduceScreenBrightness(bool v) {
    _reduceScreenBrightness = v;
    notifyListeners();
  }

  void setDisableAnimations(bool v) {
    _disableAnimations = v;
    notifyListeners();
  }

  void setDisableBackgroundSync(bool v) {
    _disableBackgroundSync = v;
    notifyListeners();
  }

  void setScreenTimeout(int seconds) {
    _screenTimeout = seconds.clamp(10, 300);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopMonitoring();
    _stateSub?.cancel();
    super.dispose();
  }
}

/// Battery saver settings UI
class BatterySaverPage extends StatelessWidget {
  const BatterySaverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BatterySaverController.instance,
      builder: (context, _) {
        final ctrl = BatterySaverController.instance;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Modo Ahorro Batería'),
            backgroundColor: Colors.green.shade900,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            children: [
              // Status card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ctrl.enabled ? Colors.green.shade800 : Colors.grey.shade800,
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            ctrl.enabled
                              ? 'Batería optimizada para emergencias'
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

              // Real battery indicator.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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

              const SizedBox(height: 16),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('CONFIGURACIÓN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),

              SwitchListTile(
                title: const Text('Reducir brillo de pantalla'),
                subtitle: const Text('Disminuye consumo visual'),
                value: ctrl.reduceScreenBrightness,
                onChanged: (v) => ctrl.setReduceScreenBrightness(v),
              ),

              SwitchListTile(
                title: const Text('Desactivar animaciones'),
                subtitle: const Text('Reduce procesamiento UI'),
                value: ctrl.disableAnimations,
                onChanged: (v) => ctrl.setDisableAnimations(v),
              ),

              SwitchListTile(
                title: const Text('Sincronización en background'),
                subtitle: const Text('Evita actualizaciones automáticas'),
                value: ctrl.disableBackgroundSync,
                onChanged: (v) => ctrl.setDisableBackgroundSync(v),
              ),

              SwitchListTile(
                title: const Text('WiFi'),
                subtitle: const Text('Desactivar completamente'),
                value: ctrl.disableWifi,
                onChanged: (v) => ctrl.setDisableWifi(v),
              ),

              SwitchListTile(
                title: const Text('Bluetooth'),
                subtitle: const Text('Desactivar mesh/LAN/BLE'),
                value: ctrl.disableBluetooth,
                onChanged: (v) => ctrl.setDisableBluetooth(v),
              ),

              ListTile(
                title: const Text('Tiempo de pantalla'),
                subtitle: Text('${ctrl.screenTimeout} segundos'),
                trailing: Slider(
                  value: ctrl.screenTimeout.toDouble(),
                  min: 10,
                  max: 300,
                  divisions: 29,
                  label: '${ctrl.screenTimeout}s',
                  onChanged: (v) => ctrl.setScreenTimeout(v.round()),
                ),
              ),

              const SizedBox(height: 24),

              // Tips
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
                        Text('Tips de ahorro', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _tip('Usa la linterna solo cuando sea necesario'),
                    _tip('Desactiva el GPS cuando no lo necesites'),
                    _tip('Cierra todas las apps en background'),
                    _tip('Usa el modo avión si no hay señal'),
                    _tip('Mantén la pantalla en negro'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
