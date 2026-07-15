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
import 'llama_server.dart';

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
    await stop();
    _ffiStatus = LlamaStatus.starting;
    _ffiError = null;
    notifyListeners();
    try {
      // Phones are tighter on RAM than desktops: smaller context window.
      // Apple platforms get full Metal offload; Android runs the NEON CPU
      // path (no stable GPU backend on Android yet).
      _ffi = await FfiLlamaEngine.load(path,
          nCtx: Platform.isMacOS ? 4096 : 2048,
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
    return engine.chat(history, maxTokens: 512, temp: temp);
  }
}
