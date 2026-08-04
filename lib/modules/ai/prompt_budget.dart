// Qué se sacrifica cuando la conversación no cabe en el contexto.
//
// El motor nativo recortaba por el PRINCIPIO: `tokens.erase(begin, end-budget)`.
// Eso borra el BOS y el system prompt, que es donde vive la persona del
// especialista y su regla de seguridad — en el caso de Vera, "NUNCA cambies
// cifras (tiempos, dosis, cantidades)". Se perdía en silencio, y justo en las
// conversaciones largas, que son las de alguien que lleva rato intentando que
// le ayuden.
//
// El orden de prioridad al recortar es:
//   1. El system prompt. Intocable mientras quepa algo.
//   2. La pregunta actual. Sin ella no hay nada que responder.
//   3. Los turnos recientes.
//   4. Los turnos viejos — lo primero que se suelta.

/// Caracteres por token, aproximado. Gemma y Qwen rondan 3,5-4,5 en español;
/// se usa el extremo BAJO a propósito, porque quedarse corto solo cuesta un
/// turno viejo de más, y pasarse cuesta el system prompt entero.
const int charsPerToken = 3;

/// Cuántos caracteres de prompt caben dejando sitio para la respuesta.
///
/// Refleja el mismo cálculo del motor nativo (n_ctx − max_tokens − 8), pero en
/// caracteres y con margen: si Dart entrega algo que ya cabe, la truncación
/// destructiva de allá abajo no llega a dispararse nunca.
int promptBudgetChars({required int nCtx, required int maxTokens}) {
  // El −16 (en vez del −8 nativo) es margen para la plantilla de chat, que
  // añade tokens de rol que no están en el texto que medimos aquí.
  final tokens = nCtx - maxTokens - 16;
  if (tokens <= 0) return 0;
  return tokens * charsPerToken;
}

/// Recorta [history] para que quepa en [budgetChars] sin perder lo que
/// importa. Devuelve una lista nueva; no modifica la original.
List<Map<String, String>> fitHistory(
  List<Map<String, String>> history, {
  required int budgetChars,
}) {
  if (history.isEmpty) return const [];

  int len(Map<String, String> m) => (m['content'] ?? '').length;
  final total = history.fold<int>(0, (a, m) => a + len(m));
  if (total <= budgetChars) return List.of(history);

  final system =
      history.first['role'] == 'system' ? history.first : null;
  final rest = system == null ? history : history.sublist(1);

  // Caso extremo: ni el system prompt cabe. Se recorta por el FINAL, donde
  // están las fuentes del RAG, nunca por delante, donde están la persona y la
  // regla de seguridad.
  if (system != null && len(system) >= budgetChars) {
    return [
      {
        'role': 'system',
        'content': (system['content'] ?? '').substring(0, budgetChars),
      }
    ];
  }

  var room = budgetChars - (system == null ? 0 : len(system));
  final kept = <Map<String, String>>[];

  // De atrás hacia delante: lo reciente vale más que lo viejo. La pregunta
  // actual es la última y entra siempre primero.
  for (var i = rest.length - 1; i >= 0; i--) {
    final m = rest[i];
    if (len(m) > room) break;
    kept.insert(0, m);
    room -= len(m);
  }

  // Nunca dejar una respuesta sin la pregunta que la provocó: al modelo le
  // confunde y al usuario le sale un asistente que contesta solo.
  while (kept.isNotEmpty && kept.first['role'] == 'assistant') {
    kept.removeAt(0);
  }

  // Si no cupo ni la pregunta actual, se manda igual: mejor una pregunta
  // truncada por el motor que ninguna pregunta.
  if (kept.isEmpty && rest.isNotEmpty) kept.add(rest.last);

  return [if (system != null) system, ...kept];
}
