import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/emergency_guide_tutorials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<String> safetyTokens(String text) {
    final matches = RegExp(
      r'\d+(?:[.,]\d+)?(?:\s?(?:%|°[CF]|kg|mg|mcg|µg|mL|ml|dL|L|mm|cm|km|m))?(?![A-Za-z])',
    ).allMatches(text);
    final tokens = matches
        .map((match) => match.group(0)!.replaceAll(RegExp(r'\s+'), ''))
        .toList()
      ..sort();
    return tokens;
  }

  List<String> numericValues(String text) {
    final values = RegExp(r'\d+(?:[.,]\d+)?')
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList()
      ..sort();
    return values;
  }

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

  test('captions críticos conservan la técnica AHA 2025 y torniquete seguro',
      () {
    final infant = EmergencyGuideTutorials.forGuide('rcp_nino_bebe')!;
    final choking = EmergencyGuideTutorials.forGuide('atragantamiento')!;
    final bleeding = EmergencyGuideTutorials.forGuide('hemorragia_severa')!;

    expect(
        infant.steps[1].captionEs.toLowerCase(), contains('base de una mano'));
    expect(
        infant.steps[1].captionEn.toLowerCase(), contains('heel of one hand'));
    expect(
        infant.steps[1].captionEs.toLowerCase(), isNot(contains('dos dedos')));
    expect(infant.steps[1].captionEn.toLowerCase(),
        isNot(contains('two fingers')));
    expect(choking.steps[0].captionEs, contains('5'));
    expect(choking.steps[1].captionEs, contains('5'));
    expect(bleeding.steps[2].captionEs, contains('5–7 cm por encima'));
    expect(bleeding.steps[2].captionEn, contains('5–7 cm above'));
  });

  test('201 pasos tienen siete captions sin fallback y preservan tokens', () {
    const languages = {'es', 'en', 'pt', 'fr', 'zh', 'ja', 'ht'};
    var stepCount = 0;

    for (final id in EmergencyGuideTutorials.guideIds) {
      final tutorial = EmergencyGuideTutorials.forGuide(id)!;
      expect(tutorial.steps, hasLength(3), reason: id);
      for (final step in tutorial.steps) {
        stepCount++;
        expect(step.captions.keys.toSet(), languages,
            reason: '$id paso ${step.number} no tiene exactamente 7 idiomas');
        final sourceCaption = step.captions['es']!;
        final expectedNumbers = numericValues(sourceCaption);
        final requiredUnitTokens = safetyTokens(sourceCaption)
            .where((token) => RegExp(r'[^\d.,]').hasMatch(token))
            .toList();
        for (final language in languages) {
          final caption = step.captions[language]!;
          expect(caption.trim(), isNotEmpty,
              reason: '$id paso ${step.number}/$language vacío');
          expect(step.captionFor(language), caption,
              reason: '$id paso ${step.number}/$language usó fallback');
          expect(numericValues(caption), expectedNumbers,
              reason: '$id paso ${step.number}/$language alteró números');
          final translatedTokens = safetyTokens(caption);
          for (final token in requiredUnitTokens) {
            expect(translatedTokens, contains(token),
                reason: '$id paso ${step.number}/$language alteró $token');
          }
        }
      }
    }

    expect(stepCount, 201);
  });

  test('locales regionales normalizan sin fallback a idiomas no soportados',
      () {
    final step = EmergencyGuideTutorials.forGuide('desierto_agua')!.steps.first;

    expect(step.captionFor('pt-BR'), step.captions['pt']);
    expect(step.captionFor('zh_CN'), step.captions['zh']);
    expect(() => step.captionFor('de-DE'), throwsUnsupportedError);
    expect(() => step.altFor('de-DE'), throwsUnsupportedError);
  });

  test('los 67 tutoriales PNG decodifican en alta resolución horizontal',
      () async {
    expect(EmergencyGuideTutorials.guideIds, hasLength(67));

    for (final id in EmergencyGuideTutorials.guideIds) {
      final tutorial = EmergencyGuideTutorials.forGuide(id)!;
      final data = await rootBundle.load(tutorial.assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();

      expect(frame.image.width, greaterThanOrEqualTo(1000), reason: id);
      expect(frame.image.height, greaterThanOrEqualTo(500), reason: id);
      expect(frame.image.width, greaterThan(frame.image.height), reason: id);

      frame.image.dispose();
      codec.dispose();
    }
  });
}
