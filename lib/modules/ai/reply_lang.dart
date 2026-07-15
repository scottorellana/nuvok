// Detects which language the user WROTE in, so the specialists answer in the
// language of the question instead of the language of the app UI. The app
// follows the DEVICE language by default, so a phone set to English produced
// English answers even for questions asked in Spanish — the #1 complaint of
// real bilingual households. Pure and offline: unicode ranges for zh/ja plus
// tiny stopword lists for the latin languages. When the signal is weak (SOS,
// numbers, single ambiguous word) it falls back to the app language.

/// Words that are near-exclusive to each latin-script language among the 7
/// the app ships. Deliberately small: distinctive beats exhaustive, and a tie
/// falls back to [appLang] anyway.
const Map<String, Set<String>> _stopwords = {
  'es': {
    'el', 'la', 'los', 'las', 'una', 'que', 'qué', 'cómo', 'para', 'por',
    'con', 'del', 'es', 'está', 'estoy', 'tengo', 'hacer', 'puedo', 'dónde',
    'cuándo', 'mi', 'yo', 'no', 'sí', 'ayuda', 'necesito', 'hago', 'si',
    'agua', 'y', 'un', 'me', 'se', 'herida', 'cuando', 'como', 'donde',
  },
  'en': {
    'the', 'a', 'an', 'and', 'is', 'are', 'i', 'you', 'to', 'of', 'in',
    'for', 'with', 'how', 'what', 'where', 'when', 'can', 'do', 'does',
    'my', 'me', 'not', 'help', 'need', 'water', 'if', 'on', 'burn', 'treat',
    'find', 'finding', 'clean',
  },
  'pt': {
    'o', 'os', 'uma', 'em', 'não', 'é', 'estou', 'tenho', 'fazer', 'posso',
    'onde', 'quando', 'meu', 'minha', 'ajuda', 'preciso', 'você', 'dos',
    'das', 'com', 'para', 'consigo', 'bem', 'de',
  },
  'fr': {
    'le', 'les', 'une', 'et', 'est', 'je', 'faire', 'puis', 'où', 'quand',
    'mon', 'ma', 'ne', 'pas', 'aide', 'besoin', 'comment', 'pour', 'avec',
    'eau', "j'ai", "l'eau", "d'aide", 'purifier',
  },
  'ht': {
    'mwen', 'ou', 'li', 'nou', 'yo', 'ki', 'sa', 'pou', 'ak', 'nan', 'se',
    'gen', 'fè', 'kote', 'kijan', 'èske', 'bezwen', 'èd', 'dlo', 'pwòp',
    'jwenn',
  },
};

/// Characters that only Spanish uses among the app's languages — one hit is
/// already a decision (¿cómo?, señal, ¡ayuda!).
final RegExp _spanishMarks = RegExp(r'[¿¡ñÑ]');

final RegExp _kana = RegExp(r'[぀-ヿ]'); // hiragana + katakana
final RegExp _cjk = RegExp(r'[一-鿿]'); // han ideographs

/// Language the reply should be written in: the language of [text] when it
/// is recognizable, otherwise [appLang]. Returns one of the 7 app language
/// codes (es, en, pt, fr, zh, ja, ht).
String detectReplyLang(String text, {required String appLang}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return appLang;

  // Scripts decide instantly: kana is Japanese; han without kana is Chinese.
  if (_kana.hasMatch(trimmed)) return 'ja';
  if (_cjk.hasMatch(trimmed)) return 'zh';
  if (_spanishMarks.hasMatch(trimmed)) return 'es';

  final words = trimmed
      .toLowerCase()
      .split(RegExp(r'[^a-záéíóúüñàèìòùâêîôûãõçäëïöœ' "'" r']+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return appLang;

  final scores = <String, int>{};
  for (final entry in _stopwords.entries) {
    var score = 0;
    for (final w in words) {
      if (entry.value.contains(w)) score++;
    }
    if (score > 0) scores[entry.key] = score;
  }
  if (scores.isEmpty) return appLang;

  // Highest score wins; ties (usually es/pt cognates) prefer the app
  // language when it is one of the tied candidates, else lexicographic-by-
  // score order keeps it deterministic.
  final best = scores.values.reduce((a, b) => a > b ? a : b);
  final winners = scores.entries
      .where((e) => e.value == best)
      .map((e) => e.key)
      .toList();
  if (winners.length == 1) return winners.first;
  if (winners.contains(appLang)) return appLang;
  return winners.first;
}
