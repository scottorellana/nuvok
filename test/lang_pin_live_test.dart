// Verificación REAL del fix de idioma con el modelo del usuario (Qwen 0.5B):
// fuente en inglés + pregunta en español debe dar respuesta en español.
// Se salta sola si el modelo o la dylib no están (CI).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/library_retriever.dart';
import 'package:nuvok/modules/ai/llama_ffi.dart';

Future<void> main() async {
  test('grounded en fuente inglesa responde en español (modelo real)',
      () async {
    final home = Platform.environment['HOME']!;
    final model = '$home/nuvok/models/qwen2.5-0.5b-instruct-q4_k_m.gguf';
    final dylib = '${Directory.current.path}/native/out/macos/libppllm.dylib';
    if (!File(model).existsSync() || !File(dylib).existsSync()) {
      markTestSkipped('sin modelo local o dylib');
      return;
    }
    FfiLlamaEngine.debugSetLibraryPath(dylib);
    final engine = await FfiLlamaEngine.load(model, nCtx: 4096);

    final sources = [
      RetrievedSource(
        title: 'Water purification',
        book: 'Wikipedia',
        path: 'A/Water_purification',
        text: 'Water purification is the process of removing undesirable '
            'chemicals, biological contaminants, suspended solids, and gases '
            'from water. Boiling water for one minute kills most pathogens. '
            'At altitudes above 2000 meters, boil for three minutes. '
            'Household bleach (sodium hypochlorite) can disinfect water: add '
            'two drops per liter of clear water and wait thirty minutes '
            'before drinking.',
      ),
    ];
    final prompt =
        LibraryRetriever.buildGroundedSystemPrompt(sources, replyLang: 'es');
    // Lo mismo que arma AiPage._send: recordatorio pegado a la pregunta.
    final question = '¿Cómo purifico agua para poder beberla?\n\n'
        '${LibraryRetriever.languageReminder('es')}';

    // La generación a temp 0.7 es estocástica: se exige mayoría de 3.
    var spanish = 0;
    for (var i = 0; i < 3; i++) {
      final reply = StringBuffer();
      await for (final piece in engine.chat([
        {'role': 'system', 'content': prompt},
        {'role': 'user', 'content': question},
      ], maxTokens: 160, temp: 0.7)) {
        reply.write(piece);
      }
      final text = reply.toString().toLowerCase();
      expect(text.trim(), isNotEmpty);
      final spanishMarkers = ['agua', 'minutos', 'hervir', 'proceso', 'se ']
          .where(text.contains)
          .length;
      final englishMarkers = [
        'water purification',
        'the process',
        'before drinking',
        'boiling water for'
      ].where(text.contains).length;
      final isSpanish = spanishMarkers > englishMarkers;
      if (isSpanish) spanish++;
      // ignore: avoid_print
      print('[intento ${i + 1}] ${isSpanish ? "ESPAÑOL" : "INGLÉS"}: $reply');
    }
    engine.dispose();
    expect(spanish, greaterThanOrEqualTo(2),
        reason: 'la mayoría de respuestas debe salir en español');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
