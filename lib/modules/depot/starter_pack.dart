// The "Paquete inicial": a curated set of survival and first-aid references
// that Nuvok offers to download on first run, matched to the user's
// language. We resolve titles against the live Kiwix catalog instead of
// hardcoding filenames, so it keeps working as content is re-versioned.
import 'dart:io';
import 'dart:ui';

import 'kiwix_catalog.dart';

class StarterItem {
  StarterItem({
    required this.category,
    required this.queries,
    required this.description,
  });

  /// Human label, e.g. "Primeros auxilios y medicina".
  final String category;

  /// Catalog search terms tried in order until one returns a result.
  final List<String> queries;

  /// One-line explanation shown to the user.
  final String description;
}

class StarterCandidate {
  StarterCandidate(this.item, this.result);
  final StarterItem item;
  final CatalogItem result;
}

class StarterPack {
  /// Kiwix language code (ISO 639-3) for the current system language,
  /// falling back to English.
  static String systemLang() {
    final code = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    switch (code) {
      case 'es':
        return 'spa';
      case 'en':
        return 'eng';
      case 'fr':
        return 'fra';
      case 'pt':
        return 'por';
      case 'de':
        return 'deu';
      default:
        return 'eng';
    }
  }

  /// Curated downloadable content packs. They resolve through the live Kiwix
  /// catalog when internet is available; once downloaded, the ZIM files remain
  /// available forever without internet.
  static List<StarterItem> itemsFor(String lang) {
    final isEs = lang == 'spa';
    return [
      StarterItem(
        category:
            isEs ? 'Primeros auxilios y medicina' : 'First aid & medicine',
        // WikiMed / Wikipedia Médica is Kiwix's offline medical encyclopedia
        // (includes first-aid procedures); MedlinePlus is a solid fallback.
        queries: isEs
            ? ['Wikipedia Médica', 'MedlinePlus', 'medicina']
            : ['WikiMed Medical Encyclopedia', 'MedlinePlus', 'medicine'],
        description: isEs
            ? 'Enciclopedia médica offline con primeros auxilios, síntomas '
                'y tratamientos.'
            : 'Offline medical encyclopedia with first aid, symptoms and '
                'treatments.',
      ),
      StarterItem(
        category: isEs
            ? 'Supervivencia y autosuficiencia'
            : 'Survival & self-reliance',
        // Kiwix has little survival content in Spanish, so we search Spanish
        // terms first and let resolve()'s language-agnostic fallback pick up
        // the English manuals (Learning Self-Reliance / Canadian Nuvok)
        // when no localized ZIM exists.
        queries: isEs
            ? ['supervivencia', 'Learning Self-Reliance', 'Canadian Nuvok']
            : ['Learning Self-Reliance', 'Canadian Nuvok', 'survival'],
        description: isEs
            ? 'Guías de supervivencia, autosuficiencia y preparación.'
            : 'Guides on survival, self-reliance and preparedness.',
      ),
      StarterItem(
        category: isEs
            ? 'Agua, saneamiento e higiene'
            : 'Water, sanitation & hygiene',
        queries: isEs
            ? ['agua potable', 'saneamiento', 'higiene']
            : ['drinking water', 'sanitation', 'hygiene'],
        description: isEs
            ? 'Referencias para potabilizar agua, prevenir enfermedades y '
                'mantener higiene en cortes de servicio.'
            : 'References for safe water, disease prevention and hygiene '
                'during outages.',
      ),
      StarterItem(
        category: isEs ? 'Desastres naturales' : 'Natural disasters',
        queries: isEs
            ? [
                'terremoto inundación huracán',
                'desastres naturales',
                'emergencias'
              ]
            : [
                'earthquake flood hurricane',
                'natural disasters',
                'emergency management'
              ],
        description: isEs
            ? 'Preparación y respuesta para terremotos, inundaciones, huracanes '
                'y emergencias grandes.'
            : 'Preparedness and response for earthquakes, floods, hurricanes '
                'and major emergencies.',
      ),
      StarterItem(
        category: isEs ? 'Alimentos y autosuficiencia' : 'Food & self-reliance',
        queries: isEs
            ? ['conservación de alimentos', 'agricultura', 'autosuficiencia']
            : ['food preservation', 'agriculture', 'self reliance'],
        description: isEs
            ? 'Conservación, huertos, cocina básica y manejo de alimentos '
                'durante emergencias.'
            : 'Food preservation, gardening, basic cooking and food handling '
                'during emergencies.',
      ),
    ];
  }

  /// Resolves each starter item against the live catalog. Requires internet;
  /// throws (caller shows an offline message) if the catalog is unreachable.
  static Future<List<StarterCandidate>> resolve({String? lang}) async {
    final language = lang ?? systemLang();
    final candidates = <StarterCandidate>[];
    for (final item in itemsFor(language)) {
      CatalogItem? found;
      for (final q in item.queries) {
        final results =
            await KiwixCatalog.search(query: q, lang: language, count: 5);
        if (results.isNotEmpty) {
          // Prefer a title that actually contains a query word.
          found = results.firstWhere(
            (r) => item.queries
                .any((q) => r.title.toLowerCase().contains(q.toLowerCase())),
            orElse: () => results.first,
          );
          break;
        }
      }
      // Last resort: try without a language filter so the user still gets
      // something useful (e.g. English manual when no localized one exists).
      if (found == null) {
        for (final q in item.queries) {
          final results = await KiwixCatalog.search(query: q, count: 5);
          if (results.isNotEmpty) {
            found = results.first;
            break;
          }
        }
      }
      if (found != null) candidates.add(StarterCandidate(item, found));
    }
    return candidates;
  }

  /// True when the library already contains a medical and a survival ZIM,
  /// so we can stop nudging the user.
  static bool alreadyHasEssentials(List<File> zims) {
    final names = zims.map((f) => f.uri.pathSegments.last.toLowerCase());
    final hasMed = names.any((n) =>
        n.contains('med') ||
        n.contains('health') ||
        n.contains('salud') ||
        n.contains('medic'));
    final hasSurvival = names.any((n) =>
        n.contains('surv') ||
        n.contains('reliance') ||
        n.contains('Nuvok') ||
        n.contains('superviv'));
    return hasMed && hasSurvival;
  }
}
