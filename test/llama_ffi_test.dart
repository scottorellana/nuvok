import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/llama_ffi.dart';

// El motor de IA embebido (llama.cpp in-process via FFI) es lo que hace que
// el asistente funcione en iPhone. Este test lo ejercita DE VERDAD: carga la
// dylib compilada y un modelo real, aplica la plantilla de chat del modelo y
// genera tokens. Se salta limpio si los artefactos no están (CI sin build
// nativo o sin modelo descargado).
void main() {
  final dylib = File('native/out/macos/libppllm.dylib');
  final installedModel = File(
      '${Platform.environment['HOME']}/Nuvok/models/qwen2.5-0.5b-instruct-q4_k_m.gguf');
  final bundledModel =
      File('assets/bundled_library/models/qwen2.5-0.5b-instruct-q4_k_m.gguf');
  final model = installedModel.existsSync() ? installedModel : bundledModel;

  test('el motor FFI carga un modelo y genera texto real', () async {
    if (!dylib.existsSync() || !model.existsSync()) {
      markTestSkipped('sin libppllm.dylib o sin modelo local');
      return;
    }
    FfiLlamaEngine.debugSetLibraryPath(dylib.absolute.path);
    final engine = await FfiLlamaEngine.load(model.path, nCtx: 1024);
    addTearDown(engine.dispose);

    // La plantilla del modelo produce un prompt con los roles marcados.
    final prompt = engine.applyTemplate([
      {'role': 'system', 'content': 'Responde en una palabra.'},
      {'role': 'user', 'content': 'di hola'},
    ]);
    expect(prompt, contains('hola'));
    expect(prompt.length, greaterThan(20),
        reason: 'el template añade estructura alrededor del contenido');

    // Generación real: llegan tokens y el stream cierra solo.
    final out = StringBuffer();
    await for (final piece in engine.chat([
      {'role': 'user', 'content': 'Di "hola" y nada más.'},
    ], maxTokens: 16, temp: 0)) {
      out.write(piece);
    }
    expect(out.toString().trim(), isNotEmpty,
        reason: 'el modelo debe producir texto');
    expect(engine.busy, isFalse, reason: 'al cerrar el stream queda libre');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
