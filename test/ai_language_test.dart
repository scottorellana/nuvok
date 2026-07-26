import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/ai/library_retriever.dart';

// El asistente debe hablar el idioma de la app: cada idioma soportado tiene
// su system prompt que FIJA el idioma de respuesta (los modelos 1B obedecen
// mejor una instrucción explícita que "responde en el idioma del usuario").
// Las claves de estado del chat existen en los 4 idiomas completos.
void main() {
  test('las claves de estado del asistente existen (ES/EN/PT/FR)', () {
    for (final key in ['aiSearchingGuides', 'aiSearchingLibrary']) {
      final map = AppStrings.allKeys[key];
      expect(map, isNotNull, reason: 'clave $key registrada');
      for (final lang in ['es', 'en', 'pt', 'fr']) {
        expect(map![lang], isNotNull, reason: '$key sin $lang');
      }
    }
  });

  // Bug real: con la biblioteca activada el prompt grounded reemplazaba al
  // que fijaba el idioma, y "responde en el idioma del usuario" no basta —
  // con fuentes de Wikipedia en inglés un modelo 0.5B contesta en inglés.
  test('el prompt grounded FIJA el idioma de respuesta explícitamente', () {
    final sources = [
      RetrievedSource(
        title: 'Water purification',
        book: 'Wikipedia',
        path: 'A/Water_purification',
        text: 'Water purification is the process of removing contaminants.',
      ),
    ];
    for (final entry in {'es': 'español', 'fr': 'français', 'pt': 'português'}
        .entries) {
      final prompt = LibraryRetriever.buildGroundedSystemPrompt(sources,
          replyLang: entry.key);
      expect(prompt, contains('SIEMPRE en ${entry.value}'),
          reason: 'el idioma ${entry.key} debe quedar fijado por nombre');
      expect(prompt, isNot(contains('idioma del usuario')),
          reason: 'la instrucción vaga no debe volver');
      // Los modelos pequeños pesan más el final del prompt: el recordatorio
      // debe ir DESPUÉS de las fuentes, no solo antes.
      expect(
          prompt.indexOf('SIEMPRE en ${entry.value}', prompt.indexOf('FIN DE FUENTES')),
          greaterThan(0),
          reason: 'recordatorio de idioma tras las fuentes (${entry.key})');
    }
  });

  test('languageReminder cubre los 7 idiomas y cae a español', () {
    for (final code in ['es', 'en', 'pt', 'fr', 'zh', 'ja', 'ht']) {
      expect(LibraryRetriever.languageReminder(code).trim(), isNotEmpty,
          reason: 'recordatorio vacío para $code');
    }
    expect(LibraryRetriever.languageReminder('xx'), 'Responde en español.');
  });
}
