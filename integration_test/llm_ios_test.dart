// Prueba del motor de IA embebido EN EL RUNTIME REAL de iOS (simulador o
// dispositivo): carga ppllm.framework por FFI, descarga Qwen 0.5B si no está
// (el simulador tiene red; en un device reusa el que haya en Documents),
// aplica la plantilla del modelo y GENERA texto. Es la prueba de "el
// asistente funciona en Apple" sin depender de taps manuales.
//
// Correr: flutter test integration_test/llm_ios_test.dart -d <device-id>
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prepper_pad/modules/ai/llama_ffi.dart';

const _modelUrl =
    'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf';

Future<File> _ensureModel() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/PrepperPad/models')
    ..createSync(recursive: true);
  final f = File('${dir.path}/qwen2.5-0.5b-instruct-q4_k_m.gguf');
  if (f.existsSync() && f.lengthSync() > 400 * 1024 * 1024) return f;

  // Descarga única (~469MB). Con redirects de HuggingFace.
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  final req = await client.getUrl(Uri.parse(_modelUrl));
  req.followRedirects = true;
  final res = await req.close();
  expect(res.statusCode, 200, reason: 'descarga del modelo');
  final sink = f.openWrite();
  await res.pipe(sink);
  client.close();
  return f;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la IA local genera texto en el runtime de Apple',
      (tester) async {
    final model = await _ensureModel();

    final engine = await FfiLlamaEngine.load(model.path, nCtx: 1024);
    addTearDown(engine.dispose);

    final out = StringBuffer();
    await for (final piece in engine.chat([
      {
        'role': 'system',
        'content': 'Eres el asistente de Prepper Pad. Responde breve.'
      },
      {'role': 'user', 'content': '¿Cómo purifico agua en una emergencia?'},
    ], maxTokens: 80, temp: 0)) {
      out.write(piece);
    }
    final text = out.toString().trim();
    // ignore: avoid_print
    print('IA(iOS) → $text');
    expect(text.length, greaterThan(20),
        reason: 'el modelo debe responder de verdad');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
