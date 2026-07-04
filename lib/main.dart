import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/prepper_library.dart';
import 'modules/ai/llama_server.dart';
import 'modules/mesh/mesh_service.dart';
import 'modules/tools/battery_saver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrepperLibrary.init();
  final firstRun = !PrepperLibrary.instance.existedBefore;
  await PrepperLibrary.instance.ensure();
  // Start reading the real battery early so the level is ready when the user
  // opens Herramientas — non-blocking, failures are swallowed inside.
  BatterySaverController.instance.init();
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
