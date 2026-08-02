// Retrieval over the installed ZIM library: finds articles relevant to a
// question and returns their text as evidence the model can cite. This is
// the "grounding" layer that makes the assistant answer from the offline
// library instead of from the model's memory alone.
import 'dart:convert';

import 'package:html/parser.dart' as html;

import '../../core/nuvok_library.dart';
import '../../zim/zim_file.dart';

class RetrievedSource {
  RetrievedSource({
    required this.title,
    required this.book,
    required this.path,
    required this.text,
  });

  final String title;
  final String book; // ZIM title, e.g. "Wikipedia" or "WikiMed"
  final String path; // full ZIM path for citation/linking
  final String text; // plain-text excerpt
}

class LibraryRetriever {
  // Very common Spanish/English words that add noise to keyword matching.
  static const _stop = {
    'el',
    'la',
    'los',
    'las',
    'un',
    'una',
    'de',
    'del',
    'y',
    'o',
    'a',
    'en',
    'que',
    'como',
    'cual',
    'cuales',
    'es',
    'son',
    'para',
    'por',
    'con',
    'se',
    'su',
    'mi',
    'lo',
    'me',
    'te',
    'qué',
    'cómo',
    'cuál',
    'the',
    'an',
    'of',
    'and',
    'or',
    'to',
    'in',
    'is',
    'are',
    'for',
    'by',
    'with',
    'how',
    'what',
    'which',
    'do',
    'i',
    'my',
    'can',
  };

  static List<String> keywords(String question) {
    final words = question
        .toLowerCase()
        .replaceAll(RegExp(r'[^\wáéíóúñü\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stop.contains(w))
        .toList();
    // De-duplicate preserving order.
    final seen = <String>{};
    return words.where(seen.add).toList();
  }

  /// Searches every installed ZIM for articles matching the question and
  /// returns up to [maxSources] excerpts, longest-title-match first.
  static Future<List<RetrievedSource>> retrieve(
    String question, {
    int maxSources = 4,
    int excerptChars = 1500,
  }) async {
    final terms = keywords(question);
    if (terms.isEmpty) return [];

    final results = <RetrievedSource>[];
    final files = NuvokLibrary.instance.listZims();

    for (final file in files) {
      if (results.length >= maxSources) break;
      ZimFile? zim;
      try {
        zim = await ZimFile.open(file.path);
        final book = await zim.metadata('Title') ?? file.uri.pathSegments.last;

        // Score candidate articles by how many query terms appear in the
        // title. Search the strongest terms first via the title index.
        final candidates = <ZimSearchResult>[];
        for (final term in terms.take(4)) {
          candidates.addAll(await zim.suggest(term, limit: 6));
        }
        if (candidates.isEmpty) continue;

        final scored = <ZimSearchResult, int>{};
        for (final c in candidates) {
          final title = c.title.toLowerCase();
          scored[c] = terms.where(title.contains).length;
        }
        final ranked = scored.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final usedIndices = <int>{};
        for (final entry in ranked) {
          if (results.length >= maxSources) break;
          final sr = entry.key;
          if (!usedIndices.add(sr.entry.index)) continue;
          final blob = await zim.contentOf(sr.entry);
          if (blob == null || !blob.mimeType.startsWith('text/html')) {
            continue;
          }
          final text = _htmlToText(
              utf8.decode(blob.data, allowMalformed: true), excerptChars);
          if (text.trim().length < 80) continue;
          results.add(RetrievedSource(
            title: sr.title,
            book: book,
            path: sr.entry.fullPath,
            text: text,
          ));
        }
      } catch (_) {
        // Skip unreadable ZIMs.
      } finally {
        await zim?.close();
      }
    }
    return results;
  }

  static String _htmlToText(String htmlStr, int maxChars) {
    final doc = html.parse(htmlStr);
    // Drop non-content nodes.
    for (final sel in ['script', 'style', 'sup', 'table', 'nav']) {
      for (final e in doc.querySelectorAll(sel)) {
        e.remove();
      }
    }
    final body = doc.body ?? doc.documentElement;
    final raw = body?.text ?? '';
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= maxChars) return collapsed;
    // Cut at a sentence boundary near the limit.
    final cut = collapsed.substring(0, maxChars);
    final lastStop = cut.lastIndexOf('. ');
    return lastStop > maxChars ~/ 2 ? cut.substring(0, lastStop + 1) : '$cut…';
  }

  /// Nombre nativo de cada idioma para fijar el idioma de RESPUESTA en el
  /// prompt (los modelos pequeños obedecen mejor una instrucción explícita
  /// que "responde en el idioma del usuario").
  static const Map<String, String> langNames = {
    'es': 'español',
    'en': 'English',
    'pt': 'português',
    'fr': 'français',
    'zh': '中文',
    'ja': '日本語',
    'ht': 'kreyòl ayisyen',
  };

  /// Recordatorio corto que se pega al FINAL del mensaje del usuario. Medido
  /// con Qwen 0.5B + fuentes en inglés: el pin solo en el system prompt da
  /// 1/4 respuestas en español; con este recordatorio como últimos tokens
  /// antes de generar, 4/4. En modelos pequeños manda lo último que leen.
  static const Map<String, String> _replyReminders = {
    'es': 'Responde en español.',
    'en': 'Reply in English.',
    'pt': 'Responda em português.',
    'fr': 'Réponds en français.',
    'zh': '请用中文回答。',
    'ja': '日本語で答えてください。',
    'ht': 'Reponn an kreyòl ayisyen.',
  };

  static String languageReminder(String replyLang) =>
      _replyReminders[replyLang] ?? _replyReminders['es']!;

  /// ¿Las fuentes recuperadas tienen que ver con la pregunta? Los retrievers
  /// devuelven "lo menos malo" para CUALQUIER texto: pedirle código Python al
  /// asistente traía guías de hemorragias con reglas de citado, degradando la
  /// respuesta y quemando contexto. Esta compuerta decide si el bloque de
  /// fuentes se adjunta o si la IA responde con su conocimiento pleno.
  static bool sourcesLookRelevant(String query, List<RetrievedSource> sources) {
    if (sources.isEmpty) return false;
    final queryWords = _contentWords(query);
    if (queryWords.isEmpty) return false;
    // Con pocas palabras de contenido basta 1 coincidencia; con más, 2.
    final needed = queryWords.length <= 2 ? 1 : 2;
    for (final s in sources) {
      final sourceWords = _contentWords('${s.title} ${s.text}');
      final overlap = queryWords.where(sourceWords.contains).length;
      if (overlap >= needed) return true;
    }
    return false;
  }

  /// Chino, japonés y coreano no separan palabras con espacios: la
  /// tokenización latina devolvía CERO tokens para "如何止住严重出血" y la
  /// compuerta descartaba SIEMPRE las guías, dejando a esos idiomas sin
  /// grounding. Se indexan bigramas de caracteres, que es la técnica estándar
  /// de recuperación CJK sin diccionario.
  ///
  /// El HIRAGANA queda fuera a propósito: en japonés es gramática (partículas,
  /// terminaciones), no contenido. Incluirlo generaba bigramas de ruido
  /// ("には", "める") que inflaban el denominador y hacían fallar la compuerta
  /// aunque la palabra clave — en kanji — coincidiera exactamente.
  static final _cjk = RegExp(
      r'[\u30A0-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF\uAC00-\uD7AF]');

  /// Palabras significativas normalizadas (minúsculas, sin acentos, sin
  /// stopwords, largo ≥4) más bigramas CJK — el mismo espíritu del buscador
  /// por síntoma, extendido a las escrituras sin espacios.
  static Set<String> _contentWords(String text) {
    const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
    var t = text.toLowerCase();
    accents.forEach((k, v) => t = t.replaceAll(k, v));
    final words = t
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 4 && !_stop.contains(w))
        .toSet();
    // Bigramas de caracteres CJK contiguos.
    final chars = text.split('');
    for (var i = 0; i + 1 < chars.length; i++) {
      if (_cjk.hasMatch(chars[i]) && _cjk.hasMatch(chars[i + 1])) {
        words.add('${chars[i]}${chars[i + 1]}');
      }
    }
    return words;
  }

  /// Bloque de fuentes para APPEND al prompt de persona del especialista —
  /// NO reemplaza la persona (eso volvía genéricos a Vera/Bruno/Sabio).
  ///
  /// Equilibrio deliberado: las cifras de emergencia (tiempos, dosis,
  /// cantidades) son sagradas y salen EXACTAS de las fuentes con su cita;
  /// pero la IA conserva TODO su conocimiento general — si la pregunta va más
  /// allá del corpus, responde igual y distingue qué no viene de la
  /// biblioteca. El candado anterior ("responde SOLO con las fuentes")
  /// anulaba las capacidades del modelo.
  /// [replyLang] fija el idioma: las fuentes suelen venir en inglés y sin
  /// anclaje un modelo chico deriva al idioma de la fuente.
  static String buildSourcesBlock(List<RetrievedSource> sources,
      {String replyLang = 'es'}) {
    final langName = langNames[replyLang] ?? 'español';
    final buffer = StringBuffer()
      ..writeln(
          'Tienes FUENTES de la biblioteca offline para esta pregunta. Cita '
          'cada dato que tomes de ellas con su número entre corchetes, por '
          'ejemplo [1]. NUNCA cambies cifras (tiempos, dosis, cantidades): '
          'usa EXACTAMENTE las de las fuentes — un número equivocado puede '
          'ser peligroso. Si la pregunta va más allá de las fuentes, '
          'respóndela igual con tu conocimiento general y deja claro qué '
          'parte no viene de la biblioteca. Traduce las fuentes si están en '
          'otro idioma y responde SIEMPRE en $langName.\n')
      ..writeln('=== FUENTES ===');
    for (var i = 0; i < sources.length; i++) {
      final s = sources[i];
      buffer
        ..writeln('[${i + 1}] ${s.title} — ${s.book}')
        ..writeln(s.text)
        ..writeln();
    }
    buffer
      ..writeln('=== FIN DE FUENTES ===')
      // Los modelos pequeños pesan más lo último que leen: repetir el idioma
      // después de páginas de fuentes evita que contesten en el idioma de
      // la fuente.
      ..writeln('Recuerda: responde SIEMPRE en $langName.');
    return buffer.toString();
  }

  /// Prompt autónomo con persona genérica de asistente + fuentes. Se conserva
  /// para usos donde NO hay una persona de especialista alrededor.
  static String buildGroundedSystemPrompt(List<RetrievedSource> sources,
      {String replyLang = 'es'}) {
    final langName = langNames[replyLang] ?? 'español';
    return 'Eres el asistente de Nuvok: una IA completa que corre dentro del '
        'dispositivo, sin internet. Puedes razonar, explicar, escribir, '
        'programar, traducir y calcular con todo tu conocimiento. Para '
        'emergencias tienes además FUENTES de la biblioteca offline: úsalas '
        'con citas [1] y cifras exactas cuando respondan a la pregunta; '
        'cuando no, responde con tu conocimiento general y dilo. En temas '
        'médicos recuerda buscar ayuda profesional cuando sea posible. '
        'Responde SIEMPRE en $langName.\n\n'
        '${buildSourcesBlock(sources, replyLang: replyLang)}';
  }
}
