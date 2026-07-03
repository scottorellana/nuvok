// Emergency grounding for the assistant: the bundled life-saving guides are
// searched FIRST (they are curated and always present), then the medical
// ZIMs. When no local model is available (Android today), strictAnswer()
// returns the top guide verbatim — zero generation, zero hallucination,
// still a life-saving answer.
import '../emergency/emergency_guides.dart';
import 'library_retriever.dart';

class EmergencyRetriever {
  /// Guides first (both languages, Spanish preferred), then library ZIMs.
  static Future<List<RetrievedSource>> retrieve(String question,
      {int maxSources = 4}) async {
    final sources = <RetrievedSource>[];
    for (final lang in ['es', 'en']) {
      if (sources.length >= 2) break;
      final guides = await EmergencyGuides.load(lang);
      final hits = EmergencyGuides.search(guides, question);
      for (final g in hits.take(2 - sources.length)) {
        sources.add(RetrievedSource(
          title: g.title,
          book: lang == 'es' ? 'Guía de Emergencia' : 'Emergency Guide',
          path: 'guide:${g.lang}/${g.id}',
          text: _condense(g.body, 2200),
        ));
      }
      if (hits.isNotEmpty) break; // same guides exist in both languages
    }
    try {
      final zims = await LibraryRetriever.retrieve(question,
          maxSources: maxSources - sources.length);
      sources.addAll(zims);
    } catch (_) {}
    return sources;
  }

  /// Direct, generation-free answer straight from the best-matching guide.
  /// Used when the local model isn't installed or fails mid-emergency.
  static Future<String?> strictAnswer(String question) async {
    for (final lang in ['es', 'en']) {
      final guides = await EmergencyGuides.load(lang);
      final hits = EmergencyGuides.search(guides, question);
      if (hits.isEmpty) continue;
      final g = hits.first;
      final more = hits.skip(1).take(3).map((x) => '• ${x.title}').join('\n');
      final header = lang == 'es'
          ? '📖 Respuesta directa de la guía (IA local no disponible):'
          : '📖 Direct answer from the guide (local AI not available):';
      final also = more.isEmpty
          ? ''
          : (lang == 'es'
              ? '\n\n---\nOtras guías relacionadas (pestaña Emergencia):\n$more'
              : '\n\n---\nRelated guides (Emergency tab):\n$more');
      return '$header\n\n# ${g.title}\n\n${g.body}$also';
    }
    return null;
  }

  /// System prompt for emergency mode: actionable numbered steps, scene
  /// safety first, citations required, always close with seeking real help.
  static String buildEmergencySystemPrompt(List<RetrievedSource> sources) {
    final grounded = LibraryRetriever.buildGroundedSystemPrompt(sources);
    return 'MODO EMERGENCIA. La persona puede estar frente a una urgencia '
        'real AHORA. Responde con pasos numerados, cortos y accionables, en '
        'orden de prioridad. Primero la seguridad de la escena. Indica qué '
        'NO hacer si es crítico. Usa medidas concretas (tiempos, '
        'profundidades, proporciones). No des rodeos ni teoría. Cita las '
        'fuentes [n]. Termina SIEMPRE recordando buscar ayuda médica '
        'profesional en cuanto sea posible.\n\n$grounded';
  }

  /// Trims a guide body to its most actionable core for the prompt window.
  static String _condense(String body, int maxChars) {
    if (body.length <= maxChars) return body;
    // Prefer cutting at a section boundary.
    final cut = body.substring(0, maxChars);
    final lastSection = cut.lastIndexOf('\n## ');
    return lastSection > maxChars ~/ 2
        ? cut.substring(0, lastSection)
        : '$cut…';
  }
}
