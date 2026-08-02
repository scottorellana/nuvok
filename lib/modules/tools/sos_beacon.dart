// Modo BALIZA SOS ultra-ahorro: pantalla negra (OLED), brillo mínimo, solo
// el beacon SOS del mesh vivo, estimación honesta de horas de señal, y burst
// final de posición cuando la batería agoniza. Atrapado bajo escombros, tu
// teléfono ES tu baliza — cada hora extra de señal cuenta.
import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../../core/screen_awake.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../core/locale_service.dart';
import '../maps/location_service.dart';
import '../mesh/mesh_service.dart';

/// Horas estimadas de beacon con [batteryPercent] de carga. Modelo
/// conservador medido en campo para radios en beacon-only: ~4%/hora.
/// Puro y testeable; preferimos subestimar a prometer de más.
double sosBeaconHoursEstimate(int batteryPercent) =>
    batteryPercent <= 0 ? 0.0 : batteryPercent / 4.0;

class SosBeaconPage extends StatefulWidget {
  const SosBeaconPage({super.key});

  @override
  State<SosBeaconPage> createState() => _SosBeaconPageState();
}

class _SosBeaconPageState extends State<SosBeaconPage> {
  final _battery = Battery();
  int _level = -1;
  Timer? _poll;
  bool _burstSent = false;
  double? _prevBrightness;

  @override
  void initState() {
    super.initState();
    // SOS del mesh activo (beacon cada 60 s con posición).
    MeshService.instance.startSos(note: 'BALIZA');
    // La baliza debe emitir durante HORAS. Si la pantalla se duerme, iOS y
    // Android suspenden el isolate de Dart y la emisión se detiene sin que
    // nadie se entere: la persona cree que está pidiendo auxilio y no.
    unawaited(ScreenAwake.acquire('sos-beacon'));
    _dim();
    _tick();
    // Sondeo lento: leer batería también gasta batería.
    _poll = Timer.periodic(const Duration(minutes: 2), (_) => _tick());
  }

  Future<void> _dim() async {
    try {
      _prevBrightness = await ScreenBrightness().application;
      await ScreenBrightness().setApplicationScreenBrightness(0.01);
    } catch (_) {}
  }

  Future<void> _tick() async {
    try {
      final lvl = await _battery.batteryLevel;
      if (mounted) setState(() => _level = lvl);
      // Batería crítica: burst final de posición UNA vez, mientras el radio
      // aún puede transmitir.
      if (lvl <= 3 && !_burstSent) {
        _burstSent = true;
        final fix = await LocationService.current();
        if (fix.isOk) {
          await MeshService.instance.sendLastPositionBurst(
            lat: fix.position!.latitude,
            lon: fix.position!.longitude,
            note: 'BATERÍA CRÍTICA',
          );
        }
      }
    } catch (_) {
      // Sin plugin de batería (desktop raro): la baliza sigue emitiendo.
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(ScreenAwake.release('sos-beacon'));
    final prev = _prevBrightness;
    if (prev != null) {
      unawaited(ScreenBrightness()
          .setApplicationScreenBrightness(prev)
          .catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _level >= 0 ? sosBeaconHoursEstimate(_level) : null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.podcasts, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                tr(context, 'beaconActive'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.red,
                    fontSize: 26,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                _level >= 0
                    ? '🔋 $_level% · ~${hours!.toStringAsFixed(0)} h'
                    : '🔋 —',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                tr(context, 'beaconHint'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  MeshService.instance.cancelSos();
                  Navigator.of(context).pop();
                },
                child: Text(tr(context, 'beaconExit')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
