import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';
import 'package:nuvok/modules/emergency/emergency_guide_tutorials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = {'es', 'en', 'pt', 'fr', 'zh', 'ja', 'ht'};

  test('all runtime locales ship the same 67 emergency guide bodies', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();

    Set<String> guideIdsFor(String lang) => assets
        .where((path) => path.startsWith('assets/emergency_guides/$lang/'))
        .where((path) => path.endsWith('.md'))
        .map((path) => path.split('/').last.replaceAll('.md', ''))
        .toSet();

    final canonicalIds = guideIdsFor('es');
    expect(canonicalIds, hasLength(67));
    for (final lang in languages) {
      expect(
        guideIdsFor(lang),
        canonicalIds,
        reason: '$lang must not silently fall back to another guide language',
      );
    }
  });

  test('the runtime loader never mixes fallback languages', () async {
    for (final lang in languages) {
      final guides = await EmergencyGuides.load(lang);
      expect(guides, hasLength(67), reason: '$lang must parse all 67 guides');
      expect(guides.every((guide) => guide.lang == lang), isTrue,
          reason: '$lang must not contain fallback guide bodies');
    }
  });

  test('all 67 guides have a bundled three-panel tutorial', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();
    final canonicalIds = assets
        .where((path) => path.startsWith('assets/emergency_guides/es/'))
        .where((path) => path.endsWith('.md'))
        .map((path) => path.split('/').last.replaceAll('.md', ''))
        .toSet();

    expect(EmergencyGuideTutorials.guideIds.toSet(), canonicalIds);
    for (final id in canonicalIds) {
      final tutorial = EmergencyGuideTutorials.forGuide(id);
      expect(tutorial, isNotNull, reason: '$id is not registered');
      expect(tutorial!.steps, hasLength(3), reason: '$id must have 3 steps');
      expect(assets, contains(tutorial.assetPath), reason: '$id asset missing');
    }
  });

  test('every tutorial step has native captions for all runtime locales', () {
    for (final id in EmergencyGuideTutorials.guideIds) {
      final tutorial = EmergencyGuideTutorials.forGuide(id)!;
      for (final step in tutorial.steps) {
        expect(step.captions.keys.toSet(), languages,
            reason: '$id step ${step.number}');
        for (final lang in languages) {
          final caption = step.captions[lang];
          expect(caption, isNotNull, reason: '$id step ${step.number} $lang');
          expect(caption!.trim(), isNotEmpty,
              reason: '$id step ${step.number} $lang');
          expect(step.captionFor(lang), caption);
          expect(step.altFor(lang), contains(caption));
        }
      }
    }
  });
}
