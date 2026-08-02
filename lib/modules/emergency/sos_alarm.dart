// SOS Alarm — when a distress signal is received, this module produces
// a loud, persistent alarm that works even if the app is in background.
//
// On Android it uses a foreground service + AudioManager + wake lock.
// On desktop (macOS/Linux) it uses system sounds via platform channels.
// The alarm can be silenced only by explicit user action (never auto-dismiss).
//
// This file contains the cross-platform controller. The native Android
// code (Kotlin) for the foreground service will be wired in the build
// phase. On platforms without native support, it falls back to a
// full-screen blinking red overlay with SystemSound.alert.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/locale_service.dart';
import '../tools/whistle.dart' show CustomAudioSource;
import 'alarm_tone.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

const _alarmChannel = MethodChannel('nuvok/sos_alarm');

/// Una persona pidiendo auxilio. La nota es lo que dice DÓNDE buscarla.
class SosAlert {
  const SosAlert({required this.id, this.fromName, this.note});

  /// senderId de la malla. Es lo único único: dos vecinos pueden llamarse
  /// igual, y deduplicar por nombre borraría a una persona real.
  final String id;
  final String? fromName;
  final String? note;
}

/// Controls the SOS alarm lifecycle.
class SosAlarmController extends ChangeNotifier {
  SosAlarmController._();
  static final SosAlarmController instance = SosAlarmController._();

  /// TODOS los que están pidiendo auxilio ahora mismo, en orden de llegada.
  ///
  /// Antes esto era un solo par (nombre, nota) y el segundo SOS sobrescribía
  /// al primero. Un terremoto no manda un SOS: manda varios a la vez, y el
  /// vecino que escribió "estoy bajo el escombro del garaje" desaparecía de
  /// la pantalla sin que nadie lo hubiera leído.
  final List<SosAlert> _alerts = [];
  List<SosAlert> get alerts => List.unmodifiable(_alerts);

  bool get alarming => _alerts.isNotEmpty;

  /// Compatibilidad: el primero en pedir auxilio.
  String? get alarmFromName => _alerts.isEmpty ? null : _alerts.first.fromName;
  String? get alarmNote => _alerts.isEmpty ? null : _alerts.first.note;

  Timer? _soundTimer;
  Timer? _escalationTimer;

  /// Añade a quien pide auxilio. Si ese mismo peer repite su SOS se actualiza
  /// su nota (la más reciente es la que vale) sin reiniciar el sonido, para
  /// que la baliza que reemite cada minuto no haga tartamudear la alarma.
  void trigger({String? id, String? fromName, String? note}) {
    final wasAlarming = alarming;
    // Sin id (llamadas antiguas o par sin identidad) el nombre es lo mejor
    // que hay; el pánico es peor que una alerta duplicada.
    final key = id ?? fromName ?? '?';
    final at = _alerts.indexWhere((a) => a.id == key);
    final alert = SosAlert(id: key, fromName: fromName, note: note);
    if (at >= 0) {
      _alerts[at] = alert;
    } else {
      _alerts.add(alert);
    }
    notifyListeners();

    // Announce the SOS to screen readers so a visually-impaired user knows
    // help is needed even if they can't see the overlay. Wrapped in
    // try/catch so unit tests without TestWidgetsFlutterBinding still work.
    try {
      // ignore: deprecated_member_use
      SemanticsService.announce(
        'Alarma SOS recibida'
        '${fromName != null ? ' de $fromName' : ''}'
        '${note != null && note.isNotEmpty ? '. Nota: $note' : ''}',
        TextDirection.ltr,
      );
    } catch (_) {
      // Binding not initialized (test env) — accessibility announce is
      // best-effort. The audible alarm + UI overlay still fire.
    }

    if (!wasAlarming) {
      _startSoundLoop();
      _startEscalation();
    }
  }

  /// Quita a UNA persona de la lista (su SOS se canceló, o el usuario ya la
  /// atendió). Mientras quede alguien pidiendo auxilio la alarma sigue: callar
  /// a los demás porque uno apareció es exactamente el fallo que esto arregla.
  void dismiss(String id) {
    _alerts.removeWhere((a) => a.id == id);
    if (_alerts.isEmpty) {
      silenceAll();
    } else {
      notifyListeners();
    }
  }

  /// Silences the alarm. Called when the user taps "Entendido".
  void silence() => silenceAll();

  /// Calla todo y vacía la lista.
  void silenceAll() {
    _alerts.clear();
    _soundTimer?.cancel();
    _soundTimer = null;
    _escalationTimer?.cancel();
    _escalationTimer = null;
    _stopNativeAlarm();
    unawaited(_stopTone());
    notifyListeners();
  }

  /// Alarma AUDIBLE en bucle + vibración de refuerzo.
  ///
  /// Antes solo vibraba: un teléfono boca abajo sobre una cama, en un
  /// bolsillo o en otra habitación no despierta a nadie con vibración, así
  /// que el SOS de un vecino se perdía en silencio pese a que la app
  /// prometía una "alarma fuerte y persistente".
  void _startSoundLoop() {
    // Alarma nativa primero (sigue sonando en segundo plano en Android).
    _startNativeAlarm();
    unawaited(_startTone());

    // La vibración se mantiene como refuerzo (sordera, ruido extremo, o si
    // el audio falla en alguna plataforma).
    _soundTimer?.cancel();
    _soundTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {
        // Binding not initialized (test env) — cancel the timer so we
        // don't keep throwing every 800ms.
        _soundTimer?.cancel();
        _soundTimer = null;
      }
    });
  }

  /// Tono sintetizado en bucle con just_audio (mismo camino probado del
  /// silbato). Si el audio falla, la vibración y el overlay siguen activos:
  /// una alarma nunca debe depender de una sola vía.
  ///
  /// PEREZOSO a propósito: crear el AudioPlayer en el constructor del
  /// singleton arrancaba timers de la plataforma en CUALQUIER test que
  /// importara este archivo, aunque nunca sonara una alarma.
  AudioPlayer? _alarmPlayer;

  /// Permite apagar el tono (tests, o un usuario que solo quiera vibración
  /// por convivencia). La vibración y el overlay siguen activos: una alarma
  /// nunca debe depender de una sola vía.
  ///
  /// Apagado por defecto BAJO PRUEBAS: just_audio lanza
  /// MissingPluginException desde un gap asíncrono que ningún try/catch local
  /// puede atrapar, y eso hacía fallar tests ajenos a la alarma. El runner de
  /// flutter_test define FLUTTER_TEST=true; en la app real no existe.
  static bool audioEnabled =
      Platform.environment['FLUTTER_TEST'] != 'true';

  Future<void> _startTone() async {
    if (!audioEnabled) return;
    try {
      final player = _alarmPlayer ??= AudioPlayer();
      await player.setLoopMode(LoopMode.one);
      await player.setAudioSource(CustomAudioSource(buildAlarmWav()));
      await player.setVolume(1.0);
      await player.play();
    } catch (_) {
      // Plataforma sin audio o entorno de test: la vibración cubre.
    }
  }

  Future<void> _stopTone() async {
    try {
      await _alarmPlayer?.stop();
    } catch (_) {}
  }

  /// Escalation: after 30 seconds without acknowledgement, increase
  /// urgency by triggering native vibration pattern.
  void _startEscalation() {
    _escalationTimer?.cancel();
    _escalationTimer = Timer(const Duration(seconds: 30), () {
      if (alarming) {
        _escalateNative();
      }
    });
  }

  /// La notificación nativa lleva a quien pidió auxilio primero y, si hay
  /// más, cuántos son: en la pantalla de bloqueo no cabe la lista entera.
  void _startNativeAlarm() {
    final extra = _alerts.length - 1;
    _alarmChannel.invokeMethod('start', {
      'name': alarmFromName ?? '',
      'note': alarmNote ?? '',
      'others': extra > 0 ? extra : 0,
    }).catchError((_) {});
  }

  void _stopNativeAlarm() {
    // Fire and forget — never let native channel errors propagate
    // (especially in tests where no platform channel is registered).
    _alarmChannel.invokeMethod('stop').catchError((_) {});
  }

  void _escalateNative() {
    _alarmChannel.invokeMethod('escalate').catchError((_) {});
  }
}

/// Full-screen SOS alarm overlay. Bright red, blinking, with a large
/// "ENTENDIDO" button to dismiss. Impossible to miss.
class SosAlarmOverlay extends StatefulWidget {
  const SosAlarmOverlay({super.key});

  @override
  State<SosAlarmOverlay> createState() => _SosAlarmOverlayState();
}

class _SosAlarmOverlayState extends State<SosAlarmOverlay>
    with SingleTickerProviderStateMixin {
  final _controller = SosAlarmController.instance;
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  /// Una persona: quién es, su nota, y un botón para atenderla sin callar a
  /// los demás.
  Widget _alertBlock(BuildContext context, SosAlert a) {
    final note = a.note;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          if (a.fromName != null)
            Text(
              '${tr(context, 'sosAlarmFrom')} ${a.fromName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          if (note != null && note.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          // Solo cuando hay más de uno: con una sola persona el botón grande
          // de abajo ya hace esto, y dos botones confunden.
          if (_controller.alerts.length > 1)
            TextButton(
              onPressed: () => _controller.dismiss(a.id),
              child: Text(
                tr(context, 'sosAlarmAck'),
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _blinkCtrl]),
      builder: (context, _) {
        if (!_controller.alarming) return const SizedBox.shrink();

        final blink = _blinkCtrl.value;
        final bg = Color.lerp(Colors.red.shade900, Colors.red.shade400, blink)!;

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Semantics(
              liveRegion: true,
              label: '${tr(context, 'sosAlarmA11y')}'
                  '${_controller.alarmFromName != null ? '. ${tr(context, 'sosAlarmFrom')} ${_controller.alarmFromName}' : ''}'
                  '${_controller.alarmNote != null && _controller.alarmNote!.isNotEmpty ? '. ${tr(context, 'sosAlarmNote')}: ${_controller.alarmNote}' : ''}',
              // Scrollable y centrada: con el texto del sistema en grande
              // (personas mayores, visión reducida — quienes MÁS usan una app
              // de emergencia) el contenido desbordaba 410 px y el botón de
              // silenciar quedaba fuera de pantalla: la alarma sonaba sin
              // forma de callarla.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_rounded,
                      size: 120,
                      color: Colors.white.withValues(alpha: 0.5 + blink * 0.5)),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      tr(context, 'sosAlarmTitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // TODOS los que piden auxilio, uno debajo de otro. Cada uno
                  // con su nota: es lo que dice dónde buscar a esa persona.
                  for (final a in _controller.alerts) _alertBlock(context, a),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 280,
                    height: 80,
                    child: Semantics(
                      button: true,
                      enabled: true,
                      label: 'Entendido: silenciar la alarma SOS',
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade900,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: () => _controller.silence(),
                        child: Text(tr(context, 'sosAlarmAck')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(context, 'sosAlarmSilence'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wraps the main app, showing the SOS overlay when an alarm is active.
class SosAlarmWrapper extends StatelessWidget {
  final Widget child;
  const SosAlarmWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned.fill(child: SosAlarmOverlay()),
      ],
    );
  }
}
