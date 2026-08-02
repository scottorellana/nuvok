// Emergency grounding for the assistant: the bundled life-saving guides are
// searched FIRST (they are curated and always present), then the medical
// ZIMs. When no local model is available (Android today), strictAnswer()
// returns the top guide verbatim — zero generation, zero hallucination,
// still a life-saving answer.
import '../emergency/emergency_guides.dart';
import 'library_retriever.dart';

class EmergencyRetriever {
  /// Reordena hits: las guías del entorno ACTIVO del usuario primero — si
  /// está en el desierto, "encontrar agua" debe responder desierto, no
  /// bosque. Puro y testeable.
  /// El modo de supervivencia dice DÓNDE estás, no QUÉ le pasa a la persona.
  ///
  /// Antes reordenaba en duro — todas las guías del modo delante — y eso
  /// rompía el triaje: con el modo bosque activo, "no respira" devolvía
  /// primero la guía de incendio forestal, porque el incendio pertenece al
  /// modo y la RCP no. Ahora el entorno solo DESEMPATA entre guías de
  /// urgencia comparable: una guía vital (priority 1-2) nunca cede su sitio.
  static List<EmergencyGuide> boostByMode(
      List<EmergencyGuide> hits, String? mode) {
    if (mode == null || mode.isEmpty) return hits;
    const vital = 2; // priority 1-2 = riesgo de muerte inmediato
    final indexed = hits.indexed.toList();
    // Orden estable: primero lo vital (respetando el orden del buscador),
    // luego lo del modo, luego el resto.
    int rank((int, EmergencyGuide) e) {
      final g = e.$2;
      if (g.priority <= vital) return 0;
      return g.modes.contains(mode) ? 1 : 2;
    }

    indexed.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.$1.compareTo(b.$1);
    });
    return indexed.map((e) => e.$2).toList();
  }

  /// Guides first — EN EL IDIOMA DE LA APP, con bonus del modo de
  /// supervivencia activo; luego ZIMs.
  static Future<List<RetrievedSource>> retrieve(String question,
      {int maxSources = 4, String lang = 'es', String? mode}) async {
    final sources = <RetrievedSource>[];
    final guides = await EmergencyGuides.load(lang);
    final hits = boostByMode(EmergencyGuides.search(guides, question), mode);
    for (final g in hits.take(2)) {
      sources.add(RetrievedSource(
        title: g.title,
        book: g.lang == 'es' ? 'Guía de Emergencia' : 'Emergency Guide',
        path: 'guide:${g.lang}/${g.id}',
        text: _condense(g.body, 2200),
      ));
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
  static Future<String?> strictAnswer(String question,
      {String appLang = 'es', String? mode}) async {
    // Primero el idioma de la app. ES/EN sólo son último recurso explícito si
    // la instalación local está incompleta o corrupta.
    final ordered = <String>{appLang, 'es', 'en'}.toList();
    for (final lang in ordered) {
      final guides = await EmergencyGuides.load(lang);
      final hits = boostByMode(EmergencyGuides.search(guides, question), mode);
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
  /// Contexto de emergencia para APPEND al prompt de persona (Vera/Norte) —
  /// NO reemplaza la persona. Solo añade la línea del entorno (si hay) y las
  /// fuentes; los pasos numerados y la seguridad de la escena ya los define
  /// la persona del especialista.
  static String buildEmergencyContext(List<RetrievedSource> sources,
      {String replyLang = 'es', String? mode}) {
    final modeLine = (mode == null || mode.isEmpty)
        ? ''
        : 'El usuario declaró el entorno: $mode. Prioriza técnicas de ESE '
            'entorno.\n';
    return '$modeLine'
        '${LibraryRetriever.buildSourcesBlock(sources, replyLang: replyLang)}';
  }

  static String buildEmergencySystemPrompt(List<RetrievedSource> sources,
      {String replyLang = 'es', String? mode}) {
    final grounded =
        LibraryRetriever.buildGroundedSystemPrompt(sources, replyLang: replyLang);
    final langName = LibraryRetriever.langNames[replyLang] ?? 'español';
    final modeLine = mode == null || mode.isEmpty
        ? ''
        : 'El usuario declaró estar en el entorno: $mode. Prioriza '
            'técnicas de ESE entorno. ';
    return 'MODO EMERGENCIA. La persona puede estar frente a una urgencia '
        'real AHORA. ${modeLine}Responde con pasos numerados, cortos y accionables, en '
        'orden de prioridad. Primero la seguridad de la escena. Indica qué '
        'NO hacer si es crítico. Usa medidas concretas (tiempos, '
        'profundidades, proporciones). No des rodeos ni teoría. Cita las '
        'fuentes [n]. Si las fuentes están en otro idioma, TRADUCE: '
        'responde SIEMPRE en $langName. '
        'Termina SIEMPRE recordando buscar ayuda médica '
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
