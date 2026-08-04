// The one door to local AI for the whole app. Behind it live two engines:
// - FfiLlamaEngine: llama.cpp embedded IN-PROCESS via FFI — iOS (child
//   processes forbidden), Android (libppllm.so per ABI) and macOS (Metal),
//   so phone and computer run the exact same engine.
// - LlamaServer: llama-server child process (Windows/Linux, where we ship
//   the server binary instead of a native library).
// The UI talks only to AiEngine and cannot tell which one is running.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'llama_ffi.dart';
import 'prompt_budget.dart';
import 'llama_server.dart';

/// ¿Hace falta cargar el modelo, o el que ya está sirve?
///
/// Todos los especialistas (Vera, Bruno, Sabio…) comparten el mismo .gguf:
/// lo que los distingue es el prompt, no el modelo. Sin esta comprobación,
/// abrir cada chat descargaba y volvía a cargar el mismo archivo de 3,4 GB —
/// el gasto más caro de la app, repetido cada vez que alguien cambia de
/// especialista buscando quién le ayuda mejor.
bool needsReload({
  required LlamaStatus status,
  required String? loadedPath,
  required String wantedPath,
}) {
  if (status != LlamaStatus.running) return true;
  // "Corriendo" sin saber qué: incoherencia, mejor rehacerlo que responder
  // con un modelo desconocido.
  if (loadedPath == null) return true;
  return loadedPath != wantedPath;
}

/// Contexto que se pide al motor.
///
/// Era 2048 en teléfono, y no daba: el presupuesto real de prompt (n_ctx menos
/// los 512 de respuesta) son ~1528 tokens, mientras que el system prompt de un
/// especialista CON las fuentes del RAG llega a ~2000. Es decir, se desbordaba
/// ya en el primer mensaje, y la truncación del motor se comía la cabeza del
/// prompt. 4096 deja sitio real para dos guías, dos fuentes de biblioteca y
/// unos cuantos turnos de conversación.
///
/// El coste es la caché KV, que crece con el contexto. En Gemma 4 E2B son
/// 18.432 bytes por token repartidos entre las pocas capas que llevan KV, así
/// que pasar de 2048 a 4096 son ~38 MB más sobre un modelo de 3,4 GB: ~1%.
const int phoneContextTokens = 4096;

/// Tope de tokens por respuesta. Vive aquí porque el presupuesto de prompt se
/// calcula restándolo del contexto.
const int maxResponseTokens = 512;

/// Cuánto se espera en segundo plano antes de soltar el modelo.
///
/// Ni instantáneo ni nunca: mirar una notificación y volver no puede costar
/// recargar 3,4 GB, pero un modelo residente mientras el usuario usa la
/// linterna o la cámara es el candidato número uno a que iOS mate la app —
/// y en iOS los buffers del modelo quedan fijados por el backend Metal, así
/// que el sistema no puede reclamarlos por su cuenta.
const Duration backgroundUnloadDelay = Duration(seconds: 45);

bool shouldUnloadAfterBackground(Duration elapsed) =>
    elapsed >= backgroundUnloadDelay;

class AiEngine extends ChangeNotifier {
  AiEngine._() {
    if (!_useFfi) {
      // Mirror the process engine's state changes to our listeners.
      LlamaServer.instance.addListener(notifyListeners);
    }
  }
  static final AiEngine instance = AiEngine._();

  /// iOS, Android and macOS run llama.cpp IN-PROCESS via FFI (one engine,
  /// verified identical on all three). Windows/Linux keep the llama-server
  /// child process until libppllm ships there too.
  static bool get _useFfi =>
      Platform.isIOS || Platform.isAndroid || Platform.isMacOS;

  FfiLlamaEngine? _ffi;
  LlamaStatus _ffiStatus = LlamaStatus.stopped;
  String? _ffiError;
  String? _ffiModelPath;

  LlamaStatus get status =>
      _useFfi ? _ffiStatus : LlamaServer.instance.status;
  String? get lastError =>
      _useFfi ? _ffiError : LlamaServer.instance.lastError;
  String? get modelPath =>
      _useFfi ? _ffiModelPath : LlamaServer.instance.modelPath;

  static Future<int?> freeRamBytes() => LlamaServer.freeRamBytes();

  Future<void> start(String path) async {
    if (!_useFfi) return LlamaServer.instance.start(path);
    if (_ffiStatus == LlamaStatus.starting) return;
    // Ya está este mismo modelo cargado: no tocarlo.
    if (!needsReload(
        status: _ffiStatus, loadedPath: _ffiModelPath, wantedPath: path)) {
      return;
    }
    await stop();
    _ffiStatus = LlamaStatus.starting;
    _ffiError = null;
    notifyListeners();
    try {
      // Phones are tighter on RAM than desktops: smaller context window.
      // Apple platforms get full Metal offload; Android runs the NEON CPU
      // path (no stable GPU backend on Android yet).
      _ffi = await FfiLlamaEngine.load(path,
          nCtx: phoneContextTokens,
          nGpuLayers: Platform.isAndroid ? 0 : 99);
      _ffiModelPath = path;
      _ffiStatus = LlamaStatus.running;
    } catch (e) {
      _ffiError = '$e';
      _ffiStatus = LlamaStatus.error;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_useFfi) return LlamaServer.instance.stop();
    _ffi?.cancel();
    _ffi?.dispose();
    _ffi = null;
    _ffiModelPath = null;
    if (_ffiStatus != LlamaStatus.stopped) {
      _ffiStatus = LlamaStatus.stopped;
      notifyListeners();
    }
  }

  Stream<String> chat(List<Map<String, String>> history, {double temp = 0.7}) {
    if (!_useFfi) return LlamaServer.instance.chat(history, temp: temp);
    final engine = _ffi;
    if (engine == null) {
      return Stream.error(StateError('modelo no cargado'));
    }
    // Recortar AQUÍ, donde se sabe qué es el system prompt. El motor nativo
    // también recorta si hace falta, pero lo hace por el principio: se lleva
    // por delante la persona del especialista y su regla de no inventar
    // cifras. Entregándole algo que ya cabe, esa poda nunca se dispara.
    final fitted = fitHistory(
      history,
      budgetChars: promptBudgetChars(
          nCtx: phoneContextTokens, maxTokens: maxResponseTokens),
    );
    return engine.chat(fitted, maxTokens: maxResponseTokens, temp: temp);
  }
}
