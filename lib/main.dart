import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/prepper_library.dart';
import 'modules/ai/llama_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrepperLibrary.init();
  final firstRun = !PrepperLibrary.instance.existedBefore;
  await PrepperLibrary.instance.ensure();
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
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await LlamaServer.instance.stop();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
