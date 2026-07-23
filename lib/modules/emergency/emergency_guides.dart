// Bundled life-saving guides: plain-language, step-by-step first-aid content
// written for this product (no trademarked course names), embedded as assets
// so they work on day zero with no downloads, in all seven runtime languages.
// Frontmatter drives search: title, keywords, priority.
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

class EmergencyGuide {
  EmergencyGuide({
    required this.id,
    required this.lang,
    required this.title,
    required this.keywords,
    required this.priority,
    required this.body,
    this.modes = const [],
    this.category = 'emergencia',
  });

  final String id; // filename without extension
  final String lang; // 'es' | 'en' | 'pt' | 'fr' | 'zh' | 'ja' | 'ht'
  final String title;
  final List<String> keywords;
  final int priority; // 1 = most critical, shown first
  final String body; // markdown without the frontmatter

  /// Entornos de supervivencia donde esta guía aplica ('bosque', 'mar', …).
  /// Vacío = guía general (emergencias médicas, desastres).
  final List<String> modes;

  /// 'emergencia' | 'supervivencia' | 'clima' | 'reconstruccion'.
  final String category;
}

class EmergencyGuides {
  static final Map<String, List<EmergencyGuide>> _cache = {};

  static Future<List<EmergencyGuide>> load(String lang) async {
    final cached = _cache[lang];
    if (cached != null) return cached;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where((p) => p.startsWith('assets/emergency_guides/$lang/'))
        .where((p) => p.endsWith('.md'))
        .toList()
      ..sort();
    final guides = <EmergencyGuide>[];
    for (final path in paths) {
      try {
        final raw = await rootBundle.loadString(path);
        final guide = parse(raw,
            id: path.split('/').last.replaceAll('.md', ''), lang: lang);
        if (guide != null) guides.add(guide);
      } catch (_) {
        // A malformed guide must never break the rest.
      }
    }
    guides.sort((a, b) => a.priority.compareTo(b.priority));
    _cache[lang] = guides;
    return guides;
  }

  /// Parses `--- frontmatter ---` + markdown body.
  static EmergencyGuide? parse(String raw,
      {required String id, required String lang}) {
    var title = id;
    var keywords = <String>[];
    var priority = 9;
    var modes = <String>[];
    var category = 'emergencia';
    var body = raw;
    if (raw.startsWith('---')) {
      final end = raw.indexOf('\n---', 3);
      if (end > 0) {
        final header = raw.substring(3, end);
        body = raw.substring(end + 4).trimLeft();
        for (final line in header.split('\n')) {
          final sep = line.indexOf(':');
          if (sep <= 0) continue;
          final key = line.substring(0, sep).trim();
          final value = line.substring(sep + 1).trim();
          switch (key) {
            case 'title':
              title = value;
              break;
            case 'priority':
              priority = int.tryParse(value) ?? 9;
              break;
            case 'mode':
              modes = value
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .split(',')
                  .map((s) => s.trim().toLowerCase())
                  .where((s) => s.isNotEmpty)
                  .toList();
              break;
            case 'category':
              category = value.toLowerCase();
              break;
            case 'keywords':
              keywords = value
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .split(',')
                  .map((s) => s.trim().toLowerCase())
                  .where((s) => s.isNotEmpty)
                  .toList();
              break;
          }
        }
      }
    }
    if (body.trim().isEmpty) return null;
    return EmergencyGuide(
      id: id,
      lang: lang,
      title: title,
      keywords: keywords,
      priority: priority,
      body: body,
      modes: modes,
      category: category,
    );
  }

  /// Ranked search: exact keyword 10, partial keyword 5, title hit 8/4,
  /// body hit 1 per occurrence (capped). Empty query → all by priority.
  /// Keywords have MUCH higher weight than body matches.
  /// Ignores common Spanish stopwords like "se", "el", "la", "un", etc.
  // Lenguaje llano → keywords clínicas que YA existen en las guías. La gente
  // en pánico no escribe "atragantamiento", escribe "se atoró, está morado".
  // Cuando la consulta contiene un gatillo, se inyectan sus anclas con peso
  // alto para que la intención clínica gane a coincidencias incidentales
  // ("comida", "moto"). Los gatillos van normalizados (sin tildes).
  static const Map<String, Map<String, List<String>>> _symptomExpansions = {
    'es': {
      'no respira': ['no respira', 'rcp', 'paro cardiaco'],
      'no responde': ['inconsciente', 'rcp'],
      'no despierta': ['inconsciente', 'rcp'],
      'no reacciona': ['inconsciente', 'rcp'],
      'desplomo': ['inconsciente', 'rcp'],
      'se desmayo': ['inconsciente', 'desmayo'],
      'tirado': ['inconsciente'],
      'se ahoga': ['atragantamiento', 'asfixia'],
      'ahogando': ['atragantamiento', 'asfixia'],
      'se atoro': ['atragantamiento', 'obstruccion'],
      'atoro con': ['atragantamiento', 'obstruccion'],
      'atraganto': ['atragantamiento'],
      'morado': ['atragantamiento', 'asfixia'],
      'se puso azul': ['atragantamiento', 'asfixia'],
      'dispararon': ['herida', 'hemorragia', 'sangre'],
      'balazo': ['herida', 'hemorragia'],
      'apuñalaron': ['herida', 'hemorragia'],
      'puñalada': ['herida', 'hemorragia'],
      'cuchillada': ['herida', 'hemorragia'],
      'no para de sangrar': ['hemorragia', 'sangre'],
      'sale mucha sangre': ['hemorragia', 'sangre'],
      'se cayo': ['fractura', 'hueso roto'],
      'se rompio': ['fractura', 'hueso roto'],
      'quebro': ['fractura', 'hueso roto'],
      'dolor en el pecho': ['infarto', 'dolor pecho'],
      'dolor de pecho': ['infarto', 'dolor pecho'],
      'brazo izquierdo': ['infarto'],
      'torcio la cara': ['acv', 'derrame'],
      'habla raro': ['acv', 'derrame'],
      'convulsiona': ['convulsion'],
      'se quemo': ['quemadura'],
      'tomo veneno': ['intoxicacion', 'veneno'],
      'trago cloro': ['intoxicacion', 'veneno'],
    },
    'en': {
      'not breathing': ['not breathing', 'cpr', 'cardiac arrest'],
      'unresponsive': ['unconscious', 'cpr'],
      'wont wake': ['unconscious', 'cpr'],
      'choking': ['choking', 'airway'],
      'turning blue': ['choking', 'airway'],
      'shot': ['wound', 'bleeding'],
      'stabbed': ['wound', 'bleeding'],
      'wont stop bleeding': ['bleeding', 'blood'],
      'broke his': ['fracture', 'broken bone'],
      'chest pain': ['heart attack', 'chest'],
      'seizing': ['seizure'],
      'got burned': ['burn'],
    },
  };

  static const _childMarkers = {
    'nino', 'ninos', 'nina', 'bebe', 'bebes', 'hijo', 'hija', 'lactante',
    'nene', 'nena', 'criatura', 'child', 'baby', 'infant', 'kid', 'son',
    'daughter',
  };

  static List<EmergencyGuide> search(List<EmergencyGuide> all, String query) {
    final q = _norm(query);
    if (q.isEmpty) return List.of(all);

    // Filter out common stopwords that cause noise
    // Filter out common stopwords that cause noise (use normalized versions)
    const stopwords = {
      'se',
      'el',
      'la',
      'los',
      'las',
      'un',
      'una',
      'unos',
      'unas',
      'de',
      'del',
      'al',
      'en',
      'por',
      'para',
      'con',
      'sin',
      'sobre',
      'y',
      'o',
      'u',
      'e',
      'i',
      'a',
      'que',
      'es',
      'son',
      'esta',
      'le',
      'les',
      'me',
      'te',
      'nos',
      'os',
      'mi',
      'su',
      'yo',
      'ella',
      'ellos',
      'ellas',
      'nosotros',
      'vosotros',
      'lo',
      'si',
      'no',
      'mas',
      'muy',
      'ya',
      'toda',
      'todos',
      'todas',
      'este',
      'estos',
      'estas',
      'ese',
      'esa',
      'esos',
      'esas',
      'aquel',
      'aquella',
      'aquellos',
      'aquellas',
      'como',
      'cuando',
      'donde',
      'porque',
      'pero',
      'aunque',
      'mientras'
    };

    final terms = q
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !stopwords.contains(t))
        .toList();
    if (terms.isEmpty) return List.of(all);

    // Expansión por síntoma: gatillos en lenguaje llano → anclas clínicas.
    final lang = all.isNotEmpty ? all.first.lang : 'es';
    final expansions = _symptomExpansions[lang] ?? const {};
    final anchors = <String>{};
    for (final e in expansions.entries) {
      if (q.contains(_norm(e.key))) anchors.addAll(e.value.map(_norm));
    }
    final hasChildMarker = terms.any(_childMarkers.contains);

    final scored = <(EmergencyGuide, int)>[];
    for (final g in all) {
      var score = 0;
      final title = _norm(g.title);
      // Keywords matching is MORE IMPORTANT than body matching
      for (final t in terms) {
        for (final k in g.keywords) {
          final kn = _norm(k);
          // Exact keyword match = highest score
          if (kn == t) {
            score += 50;
          } else if (kn.startsWith(t) || t.startsWith(kn)) {
            score += 25;
          } else if (kn.contains(t) || t.contains(kn)) {
            score += 10;
          }
        }
        // Title match is important
        if (title.startsWith(t)) {
          score += 20;
        } else if (title.contains(t)) {
          score += 10;
        }
      }
      // Match de FRASE: una keyword multi-palabra ("no respira", "dolor
      // pecho") que aparece tal cual en la consulta es señal fuerte que el
      // split por palabra suelta se perdía.
      for (final k in g.keywords) {
        final kn = _norm(k);
        if (kn.contains(' ') && q.contains(kn)) score += 45;
      }
      // Anclas de síntoma: intención clínica que debe ganar al ruido.
      for (final a in anchors) {
        for (final k in g.keywords) {
          final kn = _norm(k);
          if (kn == a) {
            score += 80;
          } else if (kn.contains(a) || a.contains(kn)) {
            score += 30;
          }
        }
        if (g.id.contains(a.replaceAll(' ', '_')) || a.contains(g.id)) {
          score += 50;
        }
        if (title.contains(a)) score += 25;
      }
      // Matiz adulto/niño en RCP y atragantamiento: sin marcador de niño, la
      // versión de adulto gana; con marcador, la infantil.
      final isChildGuide = g.id.contains('nino') || g.id.contains('bebe');
      if (score > 0 && (g.id.startsWith('rcp') || isChildGuide)) {
        if (hasChildMarker && isChildGuide) score += 60;
        if (!hasChildMarker && isChildGuide) score -= 40;
      }
      // Body matches are a minor bonus, not primary
      final body = _norm(g.body);
      for (final t in terms) {
        final hits = t.allMatches(body).length;
        if (hits > 0 && hits <= 3) score += hits;
      }
      if (score > 0) scored.add((g, score));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : a.$1.priority.compareTo(b.$1.priority);
    });
    return [for (final (g, _) in scored) g];
  }

  /// Lowercase + strip accents so "corazón" matches "corazon".
  static String _norm(String s) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunAEIOUUN';
    var out = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i].toLowerCase());
    }
    return out;
  }
}
