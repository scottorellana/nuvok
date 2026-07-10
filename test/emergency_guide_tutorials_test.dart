import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_guide_tutorials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cada guía ES/EN tiene tutorial visual de tres pasos y asset offline',
      () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();

    final esIds = assets
        .where((p) => p.startsWith('assets/emergency_guides/es/'))
        .where((p) => p.endsWith('.md'))
        .map((p) => p.split('/').last.replaceAll('.md', ''))
        .toSet();
    final enIds = assets
        .where((p) => p.startsWith('assets/emergency_guides/en/'))
        .where((p) => p.endsWith('.md'))
        .map((p) => p.split('/').last.replaceAll('.md', ''))
        .toSet();

    expect(esIds, isNotEmpty);
    expect(enIds, esIds,
        reason: 'ES y EN deben compartir los mismos tutoriales visuales');

    for (final id in esIds) {
      final tutorial = EmergencyGuideTutorials.forGuide(id);
      expect(tutorial, isNotNull, reason: '$id no tiene tutorial visual');
      expect(tutorial!.steps, hasLength(3),
          reason: '$id debe tener exactamente tres pasos visuales');
      expect(assets, contains(tutorial.assetPath),
          reason: '${tutorial.assetPath} no está incluido offline');

      for (final step in tutorial.steps) {
        expect(step.captionEs.trim(), isNotEmpty,
            reason: '$id tiene caption ES vacío');
        expect(step.captionEn.trim(), isNotEmpty,
            reason: '$id tiene caption EN vacío');
        expect(step.altEs.trim(), isNotEmpty, reason: '$id tiene alt ES vacío');
        expect(step.altEn.trim(), isNotEmpty, reason: '$id tiene alt EN vacío');
      }
    }
  });

  test('captions críticos conservan la técnica AHA 2025 y torniquete seguro', () {
    final infant = EmergencyGuideTutorials.forGuide('rcp_nino_bebe')!;
    final choking = EmergencyGuideTutorials.forGuide('atragantamiento')!;
    final bleeding = EmergencyGuideTutorials.forGuide('hemorragia_severa')!;

    expect(infant.steps[1].captionEs.toLowerCase(), contains('base de una mano'));
    expect(infant.steps[1].captionEn.toLowerCase(), contains('heel of one hand'));
    expect(infant.steps[1].captionEs.toLowerCase(), isNot(contains('dos dedos')));
    expect(infant.steps[1].captionEn.toLowerCase(), isNot(contains('two fingers')));
    expect(choking.steps[0].captionEs, contains('5'));
    expect(choking.steps[1].captionEs, contains('5'));
    expect(bleeding.steps[2].captionEs, contains('5–7 cm por encima'));
    expect(bleeding.steps[2].captionEn, contains('5–7 cm above'));
  });
}
