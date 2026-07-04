import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
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
  // Start reading the real battery early so the level is ready when the user
  // opens Herramientas — non-blocking, failures are swallowed inside.
  BatterySaverController.instance.init();
  // Opportunistic update check: only does anything useful if the device has
  // internet right now; silently no-ops otherwise. Never blocks startup —
  // the app is 100% usable offline whether or not this ever completes.
  unawaited(UpdateService.instance
      .init()
      .then((_) => UpdateService.instance.check()));
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
