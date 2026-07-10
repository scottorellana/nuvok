// In-process LLM engine over Dart FFI → libppllm (llama.cpp statically
// embedded, Metal on Apple). This is the path that makes the local assistant
// work on iOS — child processes are forbidden there — and it runs identically
// on macOS/Android, so one engine serves every device.
//
// Threading: ppllm_generate streams tokens from a native thread; they arrive
// through NativeCallable.listener (async-safe) as malloc'd byte strings that
// WE free after copying. Token pieces can split UTF-8 codepoints, so bytes
// flow through utf8.decoder incrementally instead of per-piece decoding.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _TokenCbNative = Void Function(Pointer<Utf8>, Pointer<Void>);

typedef _LoadNative = Pointer<Void> Function(Pointer<Utf8>, Int32, Int32);
typedef _LoadDart = Pointer<Void> Function(Pointer<Utf8>, int, int);
typedef _TemplateNative = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Pointer<Utf8>>, Pointer<Pointer<Utf8>>, Int32);
typedef _TemplateDart = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Pointer<Utf8>>, Pointer<Pointer<Utf8>>, int);
typedef _GenerateNative = Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32,
    Float, Pointer<NativeFunction<_TokenCbNative>>, Pointer<Void>);
typedef _GenerateDart = int Function(Pointer<Void>, Pointer<Utf8>, int, double,
    Pointer<NativeFunction<_TokenCbNative>>, Pointer<Void>);
typedef _HandleNative = Void Function(Pointer<Void>);
typedef _HandleDart = void Function(Pointer<Void>);
typedef _BusyNative = Int32 Function(Pointer<Void>);
typedef _BusyDart = int Function(Pointer<Void>);
typedef _StrFreeNative = Void Function(Pointer<Utf8>);
typedef _StrFreeDart = void Function(Pointer<Utf8>);
typedef _LastErrNative = Pointer<Utf8> Function();
typedef _LastErrDart = Pointer<Utf8> Function();

class _PpLlmBindings {
  _PpLlmBindings(DynamicLibrary lib)
      : load = lib.lookupFunction<_LoadNative, _LoadDart>('ppllm_load'),
        applyTemplate = lib.lookupFunction<_TemplateNative, _TemplateDart>(
            'ppllm_apply_template'),
        generate = lib
            .lookupFunction<_GenerateNative, _GenerateDart>('ppllm_generate'),
        cancel = lib.lookupFunction<_HandleNative, _HandleDart>('ppllm_cancel'),
        busy = lib.lookupFunction<_BusyNative, _BusyDart>('ppllm_busy'),
        free = lib.lookupFunction<_HandleNative, _HandleDart>('ppllm_free'),
        stringFree = lib
            .lookupFunction<_StrFreeNative, _StrFreeDart>('ppllm_string_free'),
        lastError = lib
            .lookupFunction<_LastErrNative, _LastErrDart>('ppllm_last_error');

  final _LoadDart load;
  final _TemplateDart applyTemplate;
  final _GenerateDart generate;
  final _HandleDart cancel;
  final _BusyDart busy;
  final _HandleDart free;
  final _StrFreeDart stringFree;
  final _LastErrDart lastError;

  /// Locates libppllm for the current platform. [override] lets tools and
  /// tests point at a build output directly.
  static DynamicLibrary openLibrary({String? override}) {
    if (override != null) return DynamicLibrary.open(override);
    if (Platform.isIOS) {
      // Shipped inside ppllm.framework via the Nuvok_native pod.
      return DynamicLibrary.open('ppllm.framework/ppllm');
    }
    if (Platform.isMacOS) {
      // Packaged app first (next to libzstd in Contents/Frameworks), then
      // the development build outputs — same lookup order as libzstd.
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final home = Platform.environment['HOME'] ?? '';
      for (final path in [
        '$exeDir/../Frameworks/libppllm.dylib',
        'native/out/macos/libppllm.dylib',
        '${Directory.current.path}/native/out/macos/libppllm.dylib',
        '$home/Nuvok-pad/native/out/macos/libppllm.dylib',
      ]) {
        if (File(path).existsSync()) return DynamicLibrary.open(path);
      }
      throw UnsupportedError('No se encontró libppllm (macOS)');
    }
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libppllm.so');
    }
    return DynamicLibrary.open('libppllm.so'); // Linux
  }
}

/// One loaded model + streaming chat, matching what the assistant UI needs.
class FfiLlamaEngine {
  FfiLlamaEngine._(this._b, this._handle);

  final _PpLlmBindings _b;
  final Pointer<Void> _handle;

  static String? _libOverride;

  /// Tools/tests: point FFI at an explicit dylib path before [load].
  static void debugSetLibraryPath(String path) => _libOverride = path;

  /// Loads the model OFF the UI thread (model load takes seconds). The
  /// returned engine is bound to this isolate for generation callbacks.
  static Future<FfiLlamaEngine> load(String modelPath,
      {int nCtx = 4096, int nGpuLayers = 99}) async {
    final lib = _libOverride;
    // The heavy load happens in a worker isolate; handles are plain
    // addresses, so they cross isolates safely.
    final addr = await Isolate.run(() {
      final b = _PpLlmBindings(_PpLlmBindings.openLibrary(override: lib));
      final p = modelPath.toNativeUtf8();
      final h = b.load(p, nCtx, nGpuLayers);
      malloc.free(p);
      if (h == nullptr) {
        throw StateError(b.lastError().toDartString());
      }
      return h.address;
    });
    return FfiLlamaEngine._(
        _PpLlmBindings(_PpLlmBindings.openLibrary(override: lib)),
        Pointer<Void>.fromAddress(addr));
  }

  /// Renders [messages] ({'role','content'}) with the model's own template.
  String applyTemplate(List<Map<String, String>> messages) {
    final n = messages.length;
    final roles = malloc<Pointer<Utf8>>(n);
    final contents = malloc<Pointer<Utf8>>(n);
    for (var i = 0; i < n; i++) {
      roles[i] = (messages[i]['role'] ?? 'user').toNativeUtf8();
      contents[i] = (messages[i]['content'] ?? '').toNativeUtf8();
    }
    try {
      final out = _b.applyTemplate(_handle, roles, contents, n);
      if (out == nullptr) {
        throw StateError(_b.lastError().toDartString());
      }
      final s = out.toDartString();
      _b.stringFree(out);
      return s;
    } finally {
      for (var i = 0; i < n; i++) {
        malloc.free(roles[i]);
        malloc.free(contents[i]);
      }
      malloc.free(roles);
      malloc.free(contents);
    }
  }

  /// Streams the assistant's reply for the given chat history.
  Stream<String> chat(List<Map<String, String>> messages,
      {int maxTokens = 512, double temp = 0.7}) {
    final prompt = applyTemplate(messages);
    final bytes = StreamController<List<int>>();
    late final NativeCallable<_TokenCbNative> callable;

    void onToken(Pointer<Utf8> piece, Pointer<Void> _) {
      if (piece == nullptr) {
        bytes.close();
        callable.close();
        return;
      }
      // Copy the malloc'd bytes, then free them (contract with pp_llm).
      final len = piece.cast<Char>().length();
      bytes.add(piece.cast<Uint8>().asTypedList(len).toList());
      _b.stringFree(piece);
    }

    callable = NativeCallable<_TokenCbNative>.listener(onToken);

    final p = prompt.toNativeUtf8();
    final rc =
        _b.generate(_handle, p, maxTokens, temp, callable.nativeFunction, nullptr);
    malloc.free(p);
    if (rc != 0) {
      callable.close();
      bytes.addError(StateError('el motor está ocupado'));
      bytes.close();
    }
    // utf8.decoder reassembles codepoints split across token pieces.
    return bytes.stream.transform(utf8.decoder);
  }

  void cancel() => _b.cancel(_handle);

  bool get busy => _b.busy(_handle) != 0;

  void dispose() => _b.free(_handle);
}

extension on Pointer<Char> {
  int length() {
    var i = 0;
    while (this[i] != 0) {
      i++;
    }
    return i;
  }
}
