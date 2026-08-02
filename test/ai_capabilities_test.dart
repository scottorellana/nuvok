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

    // Chino y japonés no separan palabras con espacios: la tokenización
    // latina devolvía CERO tokens y la compuerta descartaba SIEMPRE las
    // guías. Los usuarios de esos idiomas perdían el grounding completo.
    test('chino: las guías del dominio SÍ entran', () {
      final zh = [
        RetrievedSource(
          title: '严重出血',
          book: 'Nuvok 指南',
          path: 'A/x',
          text: '直接压迫伤口十分钟不要松手。止血带绑在伤口上方5-8厘米处。',
        ),
      ];
      expect(LibraryRetriever.sourcesLookRelevant('如何止住严重出血', zh), isTrue,
          reason: 'la pregunta comparte "严重出血" con la fuente');
    });

    test('japonés: las guías del dominio SÍ entran', () {
      final ja = [
        RetrievedSource(
          title: '重度の出血',
          book: 'Nuvok ガイド',
          path: 'A/x',
          text: '傷口を十分間直接圧迫し続けます。止血帯は傷の5〜8cm上に巻きます。',
        ),
      ];
      expect(LibraryRetriever.sourcesLookRelevant('出血を止めるには', ja), isTrue);
    });

    test('CJK ajeno al tema sigue quedando fuera', () {
      final zh = [
        RetrievedSource(
          title: '严重出血',
          book: 'Nuvok 指南',
          path: 'A/x',
          text: '直接压迫伤口十分钟不要松手。',
        ),
      ];
      expect(
          LibraryRetriever.sourcesLookRelevant('用python写一个排序函数', zh), isFalse,
          reason: 'una pregunta de programación no debe arrastrar guías');
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
