// Prueba del motor de IA embebido EN EL RUNTIME REAL de iOS (simulador o
// dispositivo): carga ppllm.framework por FFI, usa el modelo que YA esté en
// Documents (p. ej. el Gemma 3 1B precargado) o descarga Qwen 0.5B, aplica la
// plantilla del modelo y GENERA texto.
//
// En device inalámbrico los prints de release no llegan al host, así que el
// test también vuelca su evidencia a Documents/PrepperPad/llm_test_result.txt
// y el host la recoge con `devicectl device copy from`.
//
// Correr: flutter run --release -t integration_test/llm_ios_test.dart -d <id>
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prepper_pad/modules/ai/llama_ffi.dart';

const _modelUrl =
    'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf';

Future<Directory> _modelsDir() async {
  final docs = await getApplicationDocumentsDirectory();
  return Directory('${docs.path}/PrepperPad/models')..createSync(recursive: true);
}

Future<File> _ensureModel() async {
  final dir = await _modelsDir();
  // Prefer whatever model the device already has (e.g. the pre-pushed
  // Gemma 3 1B) — that's the exact artifact the user runs.
  final existing = dir
      .listSync()
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.gguf') && f.lengthSync() > 300 * 1024 * 1024)
      .toList()
    ..sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
  if (existing.isNotEmpty) return existing.first;

  final f = File('${dir.path}/qwen2.5-0.5b-instruct-q4_k_m.gguf');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  final req = await client.getUrl(Uri.parse(_modelUrl));
  req.followRedirects = true;
  final res = await req.close();
  expect(res.statusCode, 200, reason: 'descarga del modelo');
  await res.pipe(f.openWrite());
  client.close();
  return f;
}

Future<void> _report(String line) async {
  // ignore: avoid_print
  print(line);
  final docs = await getApplicationDocumentsDirectory();
  File('${docs.path}/PrepperPad/llm_test_result.txt')
      .writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la IA local genera texto en el runtime de Apple',
      (tester) async {
    final docs = await getApplicationDocumentsDirectory();
    final resultFile = File('${docs.path}/PrepperPad/llm_test_result.txt');
    if (resultFile.existsSync()) resultFile.deleteSync();
    try {
      final model = await _ensureModel();
      await _report('MODELO → ${model.path.split('/').last} '
          '(${(model.lengthSync() / 1048576).toStringAsFixed(0)} MB)');

      final swLoad = Stopwatch()..start();
      final engine = await FfiLlamaEngine.load(model.path, nCtx: 1024);
      addTearDown(engine.dispose);
      await _report('CARGA → ${swLoad.elapsedMilliseconds} ms');

      final swGen = Stopwatch()..start();
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
      await _report('GEN → ${swGen.elapsedMilliseconds} ms');
      await _report('IA(iOS) → $text');
      await _report('OK');
      expect(text.length, greaterThan(20),
          reason: 'el modelo debe responder de verdad');
    } catch (e, st) {
      await _report('EXCEPCION → $e');
      await _report('$st');
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
