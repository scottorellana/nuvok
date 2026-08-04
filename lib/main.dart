import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/build_flags.dart';
import 'core/bundled_library.dart';
import 'core/locale_service.dart';
import 'core/native_licenses.dart';
import 'core/nuvok_library.dart';
import 'modules/depot/download_manager.dart';
import 'modules/ai/ai_engine.dart';
import 'modules/mesh/mesh_envelope.dart';
import 'modules/mesh/mesh_notifications.dart';
import 'modules/mesh/mesh_router.dart';
import 'modules/mesh/mesh_service.dart';
import 'modules/tools/battery_saver.dart';
import 'modules/update/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // llama.cpp (MIT) y zstd (BSD) van compilados dentro de libppllm y ambas
  // licencias obligan a incluir su aviso en cada copia distribuida. Flutter no
  // las descubre solo (no son paquetes de pub), así que se registran a mano.
  NativeLicenses.register();
  // Nada entre aquí y runApp puede tumbar el arranque. Nuvok se abre en
  // emergencias: sus guías, su brújula, su linterna y su SOS viven dentro de
  // la app y no dependen del almacenamiento externo, que tras un reinicio (o
  // con la SD fuera) puede no estar disponible todavía.
  try {
    await NuvokLibrary.init();
  } catch (e) {
    debugPrint('NuvokLibrary.init falló: $e');
  }
  // Language: a saved explicit choice wins; otherwise follow the DEVICE
  // language (this is what makes the app come up in the user's own language
  // the very first time). Must run after NuvokLibrary.init (prefs live in
  // the library root) and before runApp (first frame already localized).
  LocaleService.instance
      .init(deviceLocale: PlatformDispatcher.instance.locale);
  var firstRun = false;
  try {
    firstRun = !NuvokLibrary.instance.existedBefore;
    await NuvokLibrary.instance.ensure();
  } catch (e) {
    debugPrint('No se pudo preparar la biblioteca: $e');
  }
  // Seed the bundled starter library WITHOUT blocking the first frame: the
  // bundle can be gigabytes (tablet single-install), and awaiting it here
  // left the user staring at a white screen for the whole copy. The UI
  // modules list whatever exists and pick up new content as it lands.
  unawaited(() async {
    try {
      await BundledLibrarySeeder.seed();
    } catch (e) {
      debugPrint('sembrado de la biblioteca falló: $e');
    }
  }());
  // Retomar lo que quedó a medias. Bajar un modelo de 2 GB con la pantalla
  // apagada termina casi siempre con el sistema matando la app: la cola vivía
  // solo en memoria y esos gigabytes quedaban huérfanos en disco mientras el
  // usuario veía la descarga "sin empezar" y la relanzaba desde cero.
  try {
    for (final dir in [
      NuvokLibrary.instance.modelsDir,
      NuvokLibrary.instance.zimDir,
      NuvokLibrary.instance.mapsDir,
    ]) {
      DownloadManager.instance.restoreQueue(dir);
    }
  } catch (e) {
    debugPrint('No se pudo retomar la cola de descargas: $e');
  }
  // Local notifications so an incoming SOS/chat reaches the user with the app
  // in the background. Non-blocking; no-ops where unsupported.
  unawaited(MeshNotifications.instance.init().catchError((Object e) =>
      debugPrint('arranque en segundo plano falló: $e')));
  // Start the mesh at boot with an automatic identity: every Nuvok is
  // discoverable from the moment it opens, so in an emergency nobody is
  // invisible for not having configured anything. Non-blocking; the radios
  // self-degrade where hardware/permission is missing.
  unawaited(MeshService.instance.ensureStartedAuto().catchError((Object e) =>
      debugPrint('arranque en segundo plano falló: $e')));
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
  runApp(NuvokApp(firstRun: firstRun));
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
    //
    // AiEngine, NO LlamaServer: en iOS/Android/macOS el motor corre EN PROCESO
    // por FFI y LlamaServer está siempre parado, así que pararlo no liberaba
    // nada y el modelo de 3,4 GB se quedaba residente. AiEngine.stop() delega
    // en LlamaServer donde ese sí es el motor real (Windows/Linux), así que
    // esto cubre las cinco plataformas. Mismo fallo que ya se corrigió en
    // battery_saver.dart y que aquí había quedado vivo.
    _unloadTimer?.cancel();
    AiEngine.instance.stop();
    MeshService.instance.stop();
    super.dispose();
  }

  /// Cuenta atrás para soltar el modelo de IA tras irse a segundo plano.
  Timer? _unloadTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Track foreground so notifications only fire when off-screen.
    MeshNotifications.instance.appInForeground =
        state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      // Volvió: cancelar la descarga pendiente. Mirar una notificación y
      // volver no puede costar recargar 3,4 GB.
      _unloadTimer?.cancel();
      _unloadTimer = null;
      // Re-establish mesh presence when app comes to foreground
      MeshService.instance.onAppResumed();
      return;
    }
    // Fuera de pantalla: soltar el modelo tras un margen corto. Un .gguf
    // residente mientras el usuario usa la linterna o la cámara es el
    // candidato número uno a que iOS mate Nuvok — y ahí los buffers del
    // modelo quedan fijados por Metal, así que el sistema no puede
    // reclamarlos por su cuenta. La malla y el SOS siguen vivos: esto solo
    // suelta la IA, que se recarga sola al abrir un chat.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _unloadTimer?.cancel();
      _unloadTimer = Timer(backgroundUnloadDelay, () {
        _unloadTimer = null;
        AiEngine.instance.stop();
      });
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    _unloadTimer?.cancel();
    await AiEngine.instance.stop();
    await MeshService.instance.stop();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
