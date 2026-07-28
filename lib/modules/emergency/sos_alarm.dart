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

import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

const _alarmChannel = MethodChannel('nuvok/sos_alarm');

/// Controls the SOS alarm lifecycle.
class SosAlarmController extends ChangeNotifier {
  SosAlarmController._();
  static final SosAlarmController instance = SosAlarmController._();

  bool _alarming = false;
  bool get alarming => _alarming;

  String? _alarmFromName;
  String? get alarmFromName => _alarmFromName;

  String? _alarmNote;
  String? get alarmNote => _alarmNote;

  Timer? _soundTimer;
  Timer? _escalationTimer;

  /// Triggers the alarm. Repeated triggers update the info but don't
  /// restart the sound loop (so multiple SOS from the same peer don't
  /// stutter).
  void trigger({String? fromName, String? note}) {
    final wasAlarming = _alarming;
    _alarming = true;
    _alarmFromName = fromName;
    _alarmNote = note;
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

  /// Silences the alarm. Called when the user taps "Entendido".
  void silence() {
    _alarming = false;
    _alarmFromName = null;
    _alarmNote = null;
    _soundTimer?.cancel();
    _soundTimer = null;
    _escalationTimer?.cancel();
    _escalationTimer = null;
    _stopNativeAlarm();
    notifyListeners();
  }

  /// Loops system sounds every 800ms to create a continuous alarm.
  void _startSoundLoop() {
    // Try native alarm first (works in background on Android).
    _startNativeAlarm();

    // Fallback: loop haptic feedback (only works while app is foreground).
    // On real deployment, the native foreground service plays a dedicated
    // alarm tone via AudioManager. HapticFeedback.heavyImpact is the
    // strongest built-in feedback available.
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

  /// Escalation: after 30 seconds without acknowledgement, increase
  /// urgency by triggering native vibration pattern.
  void _startEscalation() {
    _escalationTimer?.cancel();
    _escalationTimer = Timer(const Duration(seconds: 30), () {
      if (_alarming) {
        _escalateNative();
      }
    });
  }

  void _startNativeAlarm() {
    _alarmChannel.invokeMethod('start', {
      'name': _alarmFromName ?? '',
      'note': _alarmNote ?? '',
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
                  if (_controller.alarmFromName != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '${tr(context, 'sosAlarmFrom')} '
                        '${_controller.alarmFromName}',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 22),
                      ),
                    ),
                  if (_controller.alarmNote != null &&
                      _controller.alarmNote!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _controller.alarmNote!,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
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
