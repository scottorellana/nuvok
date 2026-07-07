import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/build_flags.dart';
import 'core/bundled_library.dart';
import 'core/prepper_library.dart';
import 'modules/ai/llama_server.dart';
import 'modules/mesh/mesh_service.dart';
import 'modules/tools/battery_saver.dart';
import 'modules/update/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrepperLibrary.init();
  final firstRun = !PrepperLibrary.instance.existedBefore;
  await PrepperLibrary.instance.ensure();
  await BundledLibrarySeeder.seed();
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Fire-and-forget cleanup: dispose() is synchronous, so we can't await.
    // These calls initiate native process teardown; they don't need to complete
    // before the widget is gone.
    LlamaServer.instance.stop();
    MeshService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
