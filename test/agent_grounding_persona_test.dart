import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/ai_page.dart' show composeAgentPrompt;
import 'package:nuvok/modules/ai/library_retriever.dart';
import 'package:nuvok/modules/ai/emergency_retriever.dart';
import 'package:nuvok/modules/ai/agents/agent_catalog.dart';
import 'package:nuvok/modules/ai/agents/agent_spec.dart';

void main() {
  group('composeAgentPrompt — el grounding SUMA a la persona, no la reemplaza',
      () {
    test('con bloque de contexto conserva la persona y añade el contexto', () {
      final p = composeAgentPrompt(
          'Eres Vera, médica de emergencia de Nuvok.', '=== FUENTES ===\n[1]…');
      expect(p, contains('Eres Vera'),
          reason: 'la persona del especialista NUNCA debe perderse');
      expect(p, contains('=== FUENTES ==='));
    });

    test('sin contexto devuelve solo la persona', () {
      final p = composeAgentPrompt('Eres Vera…', '');
      expect(p, 'Eres Vera…');
    });
  });

  group('los bloques de fuentes NO reclaman una persona propia', () {
    final sources = [
      RetrievedSource(
          title: 'Quemaduras',
          book: 'Primeros auxilios',
          path: 'A/quemaduras',
          text: 'Enfriar 10 min'),
    ];

    test('buildSourcesBlock no dice "Eres el asistente"', () {
      final b = LibraryRetriever.buildSourcesBlock(sources, replyLang: 'es');
      expect(b, contains('=== FUENTES ==='));
      expect(b.toLowerCase(), isNot(contains('eres ')),
          reason: 'el bloque de fuentes no debe imponer una persona genérica');
    });

    test('buildEmergencyContext tampoco impone persona', () {
      final b = EmergencyRetriever.buildEmergencyContext(sources,
          replyLang: 'es', mode: 'water');
      expect(b, contains('=== FUENTES ==='));
      expect(b.toLowerCase(), isNot(contains('eres ')));
    });
  });

  test('Elías (apoyo emocional) NO usa grounding de guías', () {
    // Anclarlo a las guías lo convertía en un bot de "MODO EMERGENCIA, pasos
    // numerados", borrando la empatía. El apoyo emocional es prompt puro.
    expect(AgentCatalog.byId('psychologist')!.grounding, GroundingMode.none);
  });
}
