import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/ai_engine.dart';
import 'package:nuvok/modules/ai/emergency_retriever.dart';
import 'package:nuvok/modules/ai/prompt_budget.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';

/// El RAG de Nuvok no es un adorno de calidad: es una BARRERA DE SEGURIDAD.
///
/// Medido con el modelo real (gemma-4-E2B) sobre el motor real, sin fuentes:
///   "¿Le pongo hielo a una quemadura grande?"
///     → "Sí, aplicar hielo envuelto en un paño es una buena medida inicial"
///   "¿Cuándo se afloja un torniquete?"
///     → "cuando el paciente ya no presenta signos de compromiso circulatorio"
///
/// Las dos respuestas hacen daño. Inyectando la guía de Nuvok, el MISMO modelo
/// contesta "No uses hielo directo en una quemadura" y "solo en el hospital".
///
/// O sea: si las fuentes no llegan al modelo, el usuario recibe consejo que
/// lesiona. Estas pruebas vigilan los dos sitios por donde el RAG se puede
/// caer en silencio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('las guías contradicen expresamente lo que el modelo cree', () async {
    final guides = await EmergencyGuides.load('es');

    final quemaduras = guides.firstWhere((g) => g.id == 'quemaduras');
    expect(quemaduras.body.toLowerCase(), contains('hielo'),
        reason: 'si la guía no menciona el hielo, no puede corregir al modelo '
            'cuando lo recomienda');

    final hemorragia = guides.firstWhere((g) => g.id == 'hemorragia_severa');
    expect(hemorragia.body.toLowerCase(), contains('afloj'),
        reason: 'la guía tiene que decir explícitamente que el torniquete no '
            'se afloja fuera del hospital');
  });

  test('preguntar por una quemadura recupera la guía de quemaduras', () async {
    final hits = await EmergencyRetriever.retrieve(
        '¿le pongo hielo a una quemadura grande?');

    expect(hits, isNotEmpty,
        reason: 'sin fuente recuperada, el modelo responde de memoria — y de '
            'memoria dice que sí al hielo');
    expect(hits.first.title.toLowerCase(), contains('quemadura'));
  });

  test('preguntar por el torniquete recupera la guía de hemorragia', () async {
    final hits =
        await EmergencyRetriever.retrieve('¿cuándo aflojo el torniquete?');
    expect(hits, isNotEmpty);
    expect(hits.map((h) => h.text.toLowerCase()).join(' '), contains('afloj'),
        reason: 'la fuente recuperada debe traer la frase que corrige');
  });

  group('el contexto tiene que dar para las fuentes', () {
    test('una guía recuperada cabe en el presupuesto de prompt', () async {
      final hits = await EmergencyRetriever.retrieve(
          '¿le pongo hielo a una quemadura grande?');
      final bloque =
          EmergencyRetriever.buildEmergencyContext(hits, replyLang: 'es');

      final presupuesto = promptBudgetChars(
          nCtx: phoneContextTokens, maxTokens: maxResponseTokens);
      expect(bloque.length, lessThan(presupuesto),
          reason: 'si el bloque de fuentes no cabe, se recorta y el usuario '
              'recibe el consejo del modelo en vez del de la guía');
    });

    test('el recorte NUNCA se come el system prompt con las fuentes dentro',
        () async {
      final hits = await EmergencyRetriever.retrieve('quemadura hielo');
      final system = 'Eres Vera. NUNCA cambies cifras.\n\n'
          '${EmergencyRetriever.buildEmergencyContext(hits, replyLang: 'es')}';

      // Una conversación larga por delante: es el caso que rompía antes.
      final history = [
        {'role': 'system', 'content': system},
        for (var i = 0; i < 20; i++) ...[
          {'role': 'user', 'content': 'pregunta larga ${'x' * 300}'},
          {'role': 'assistant', 'content': 'respuesta larga ${'y' * 300}'},
        ],
        {'role': 'user', 'content': '¿le pongo hielo?'},
      ];

      final fitted = fitHistory(history,
          budgetChars: promptBudgetChars(
              nCtx: phoneContextTokens, maxTokens: maxResponseTokens));

      expect(fitted.first['role'], 'system');
      expect(fitted.first['content'], contains('hielo'),
          reason: 'la guía viaja DENTRO del system prompt: recortarlo por la '
              'cabeza dejaba al modelo recomendando hielo sobre una quemadura');
      expect(fitted.last['content'], contains('hielo'));
    });
  });
}
