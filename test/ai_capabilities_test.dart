import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/agent_catalog.dart';
import 'package:nuvok/modules/ai/library_retriever.dart';

/// La IA de Nuvok debe ser un asistente COMPLETO: las fuentes offline son su
/// superpoder cuando tocan, no una jaula. Antes el prompt decía "Responde
/// SOLO con base en las FUENTES" y las fuentes se pegaban a toda pregunta:
/// pedirle código Python traía guías de RCP con reglas de citado.
///
/// Lo que NO se relaja: cifras médicas/de emergencia EXACTAS de las fuentes,
/// citas [n], y el pin de idioma.
void main() {
  final fuentes = [
    RetrievedSource(
      title: 'Hemorragia severa',
      book: 'Guías Nuvok',
      path: 'A/hemorragia',
      text: 'Presión directa 10 minutos sin soltar. Torniquete 5-8 cm por '
          'encima de la herida.',
    ),
  ];

  group('el asistente con fuentes conserva todas sus capacidades', () {
    test('el prompt autónomo ya no encierra a la IA en las fuentes', () {
      final p = LibraryRetriever.buildGroundedSystemPrompt(fuentes);
      expect(p, isNot(contains('Responde SOLO')),
          reason: 'el candado total anulaba lo que el modelo sabe hacer');
      expect(p.toLowerCase(), contains('conocimiento'),
          reason: 'debe autorizar explícitamente el conocimiento general');
      // Lo que sí se conserva:
      expect(p, contains('FUENTES'));
      expect(p, contains('[1]'));
    });

    test('el bloque de fuentes permite ir más allá, sin aflojar las cifras',
        () {
      final b = LibraryRetriever.buildSourcesBlock(fuentes);
      expect(b, contains('EXACTAMENTE'),
          reason: 'dosis/tiempos/cantidades siguen siendo sagrados');
      expect(b, contains('[1]'));
      expect(b, contains('SIEMPRE en español'));
      expect(b.toLowerCase(), contains('conocimiento'),
          reason: 'si la pregunta excede las fuentes, responde igual y '
              'distingue qué no viene de la biblioteca');
      expect(b, isNot(contains('no inventes')),
          reason: 'la prohibición total bloqueaba preguntas legítimas fuera '
              'del corpus');
    });
  });

  group('compuerta de relevancia: fuentes solo cuando vienen al caso', () {
    test('pregunta del dominio → las fuentes entran', () {
      expect(
          LibraryRetriever.sourcesLookRelevant(
              'cómo detengo una hemorragia con torniquete', fuentes),
          isTrue);
    });

    test('pregunta ajena (código, cartas, matemáticas) → fuera', () {
      expect(
          LibraryRetriever.sourcesLookRelevant(
              'escríbeme una función en python que ordene una lista', fuentes),
          isFalse,
          reason: 'pegarle guías de hemorragias a una pregunta de código '
              'degrada la respuesta y quema contexto');
      expect(
          LibraryRetriever.sourcesLookRelevant(
              'redacta una carta de renuncia formal', fuentes),
          isFalse);
    });

    test('sin fuentes no hay nada que decidir', () {
      expect(LibraryRetriever.sourcesLookRelevant('lo que sea', const []),
          isFalse);
    });

    test('acentos y mayúsculas no engañan a la compuerta', () {
      expect(
          LibraryRetriever.sourcesLookRelevant('HEMORRAGIA SEVERA', fuentes),
          isTrue);
    });
  });

  group('Sabio: bibliotecario estricto con salida honesta', () {
    test('cita como siempre, pero ya no tiene prohibido saber', () {
      final sabio = AgentCatalog.byId('librarian');
      expect(sabio, isNotNull);
      final es = sabio!.system('es');
      expect(es, contains('[n]'), reason: 'la disciplina de citas se queda');
      expect(es.toLowerCase(), contains('conocimiento general'),
          reason: 'si la biblioteca no lo tiene, puede ayudar igual '
              'dejando claro que no viene de las fuentes');
    });
  });
}
