// The one door to local AI for the whole app. Behind it live two engines:
// - LlamaServer: llama-server child process (macOS/Windows/Linux — battle
//   tested here, isolates crashes from the app).
// - FfiLlamaEngine: llama.cpp embedded IN-PROCESS via FFI (iOS, where child
//   processes are forbidden; also the future path for Android).
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

  /// iOS cannot spawn llama-server; everyone else keeps the proven process.
  static bool get _useFfi => Platform.isIOS;

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
      _ffi = await FfiLlamaEngine.load(path, nCtx: 2048);
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

  Stream<String> chat(List<Map<String, String>> history) {
    if (!_useFfi) return LlamaServer.instance.chat(history);
    final engine = _ffi;
    if (engine == null) {
      return Stream.error(StateError('modelo no cargado'));
    }
    return engine.chat(history, maxTokens: 512, temp: 0.7);
  }
}
