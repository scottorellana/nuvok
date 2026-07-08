// System notifications for the mesh: an incoming SOS or chat must reach the
// user even when the app isn't on screen — the phone keeps receiving over BLE
// in the background (UIBackgroundModes bluetooth-central/peripheral on iOS).
//
// The "should we notify?" decision is a pure function ([shouldNotify]) so it
// can be unit-tested; the platform plugin calls are a thin, guarded layer that
// no-ops anywhere the plugin isn't available (tests, unsupported platforms).
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'mesh_envelope.dart';

class MeshNotifications {
  MeshNotifications._();
  static final MeshNotifications instance = MeshNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  /// Set by the app lifecycle: notifications only fire when we're NOT the
  /// foreground app (on screen the chat list and the full-screen SOS alarm
  /// already surface the event — a banner on top would be noise).
  bool appInForeground = true;

  /// Pure policy: should this envelope raise a system notification?
  static bool shouldNotify({
    required bool foreground,
    required MeshType type,
    required bool fromSelf,
  }) {
    if (fromSelf) return false; // never notify our own traffic
    if (foreground) return false; // UI/alarm already shows it
    return type == MeshType.sos || type == MeshType.chat;
  }

  Future<void> init() async {
    if (_inited) return;
    try {
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: false,
      );
      await _plugin.initialize(const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ));
      // Android needs an explicit high-importance channel for the SOS sound.
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'prepper_sos',
        'Emergencia (SOS)',
        description: 'Alertas de SOS de Prepper Pads cercanos',
        importance: Importance.max,
        playSound: true,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'prepper_chat',
        'Mensajes',
        description: 'Mensajes del mesh sin internet',
        importance: Importance.high,
      ));
      _inited = true;
    } catch (_) {
      // No plugin here (tests / unsupported) — the in-app UI still works.
    }
  }

  /// Show a notification for an incoming mesh event if policy allows.
  /// [title]/[body] are already localized/composed by the caller.
  Future<void> notify({
    required MeshType type,
    required bool fromSelf,
    required String title,
    required String body,
  }) async {
    if (!shouldNotify(
        foreground: appInForeground, type: type, fromSelf: fromSelf)) {
      return;
    }
    if (!_inited) await init();
    final isSos = type == MeshType.sos;
    try {
      await _plugin.show(
        // SOS uses a stable id so repeats replace instead of stacking; chat
        // uses a rolling id so distinct messages each show.
        isSos ? 911 : (DateTime.now().millisecondsSinceEpoch & 0x7fffffff),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            isSos ? 'prepper_sos' : 'prepper_chat',
            isSos ? 'Emergencia (SOS)' : 'Mensajes',
            importance: isSos ? Importance.max : Importance.high,
            priority: isSos ? Priority.max : Priority.high,
            category:
                isSos ? AndroidNotificationCategory.alarm : null,
            fullScreenIntent: isSos,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: isSos
                ? InterruptionLevel.critical
                : InterruptionLevel.active,
          ),
          macOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('MeshNotifications.notify failed: $e');
      }
    }
  }
}
