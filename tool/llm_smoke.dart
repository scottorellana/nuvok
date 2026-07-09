// Smoke real del motor FFI: carga Qwen 0.5B y genera una respuesta.
import 'dart:io';
import 'package:prepper_pad/modules/ai/llama_ffi.dart';

Future<void> main() async {
  FfiLlamaEngine.debugSetLibraryPath(
      '${Directory.current.path}/native/out/macos/libppllm.dylib');
  final sw = Stopwatch()..start();
  final engine = await FfiLlamaEngine.load(
      '${Platform.environment['HOME']}/PrepperPad/models/qwen2.5-0.5b-instruct-q4_k_m.gguf');
  stdout.writeln('modelo cargado en ${sw.elapsedMilliseconds}ms');
  sw.reset();
  var tokens = 0;
  await for (final piece in engine.chat([
    {'role': 'system', 'content': 'Eres el asistente de Prepper Pad. Responde breve en español.'},
    {'role': 'user', 'content': '¿Qué hago si alguien se está atragantando?'},
  ], maxTokens: 120)) {
    stdout.write(piece);
    tokens++;
  }
  stdout.writeln('\n--- $tokens piezas en ${sw.elapsedMilliseconds}ms');
  engine.dispose();
  exit(0);
}
