import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/build_flags.dart';
import 'core/bundled_library.dart';
import 'core/locale_service.dart';
import 'core/prepper_library.dart';
import 'modules/ai/llama_server.dart';
import 'modules/mesh/mesh_envelope.dart';
import 'modules/mesh/mesh_notifications.dart';
import 'modules/mesh/mesh_router.dart';
import 'modules/mesh/mesh_service.dart';
import 'modules/tools/battery_saver.dart';
import 'modules/update/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrepperLibrary.init();
  // Language: a saved explicit choice wins; otherwise follow the DEVICE
  // language (this is what makes the app come up in the user's own language
  // the very first time). Must run after PrepperLibrary.init (prefs live in
  // the library root) and before runApp (first frame already localized).
  LocaleService.instance
      .init(deviceLocale: PlatformDispatcher.instance.locale);
  final firstRun = !PrepperLibrary.instance.existedBefore;
  await PrepperLibrary.instance.ensure();
  // Seed the bundled starter library WITHOUT blocking the first frame: the
  // bundle can be gigabytes (tablet single-install), and awaiting it here
  // left the user staring at a white screen for the whole copy. The UI
  // modules list whatever exists and pick up new content as it lands.
  unawaited(BundledLibrarySeeder.seed());
  // Local notifications so an incoming SOS/chat reaches the user with the app
  // in the background. Non-blocking; no-ops where unsupported.
  unawaited(MeshNotifications.instance.init());
  // Start the mesh at boot with an automatic identity: every Prepper Pad is
  // discoverable from the moment it opens, so in an emergency nobody is
  // invisible for not having configured anything. Non-blocking; the radios
  // self-degrade where hardware/permission is missing.
  unawaited(MeshService.instance.ensureStartedAuto());
  // Start reading the real battery early so the level is ready when the user
  // opens Herramientas — non-blocking, failures are swallowed inside.
  BatterySaverController.instance.init();
  // Opportunistic update check: only does anything useful if the device has
  // internet right now; silently no-ops otherwise. Never blocks startup —
  // the app is 100% usable offline whether or not this ever completes.
  // Store builds (App Store / Play) never self-update: the stores own that.
  if (!kStoreBuild && !Platform.isIOS) {
    unawaited(UpdateService.instance
        .init()
        .then((_) => UpdateService.instance.check()));
  }
  runApp(PrepperPadApp(firstRun: firstRun));
}

/// Stops the embedded llama server when the app quits.
class AppLifecycleCleanup extends StatefulWidget {
  const AppLifecycleCleanup({super.key, required this.child});
  final Widget child;

  @override
  State<AppLifecycleCleanup> createState() => _AppLifecycleCleanupState();
}

class _AppLifecycleCleanupState extends State<AppLifecycleCleanup>
    with WidgetsBindingObserver {
  StreamSubscription? _meshSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Turn incoming mesh events into system notifications when the app is
    // backgrounded (the policy lives in MeshNotifications.shouldNotify).
    _meshSub = MeshService.instance.events.listen(_onMeshEvent);
  }

  void _onMeshEvent(MeshEvent e) {
    final fromSelf =
        e.envelope.senderId == MeshService.instance.identity?.id;
    final name = e.envelope.senderName;
    final String title;
    final String body;
    if (e.envelope.type == MeshType.sos) {
      title = '🚨 SOS — $name';
      final note = (e.payload['note'] as String?)?.trim() ?? '';
      body = note.isNotEmpty ? note : 'Pide ayuda cerca de ti';
    } else {
      title = name;
      body = (e.payload['text'] as String?)?.trim() ?? '';
    }
    MeshNotifications.instance.notify(
      type: e.envelope.type,
      fromSelf: fromSelf,
      title: title,
      body: body,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _meshSub?.cancel();
    // Fire-and-forget cleanup: dispose() is synchronous, so we can't await.
    // These calls initiate native process teardown; they don't need to complete
    // before the widget is gone.
    LlamaServer.instance.stop();
    MeshService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Track foreground so notifications only fire when off-screen.
    MeshNotifications.instance.appInForeground =
        state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      // Re-establish mesh presence when app comes to foreground
      MeshService.instance.onAppResumed();
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await LlamaServer.instance.stop();
    await MeshService.instance.stop();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
