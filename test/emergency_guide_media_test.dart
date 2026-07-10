import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_guide_media.dart';
import 'package:prepper_pad/modules/emergency/emergency_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cada guía tiene media educativa segura, offline y reproducible',
      () async {
    final guides = <EmergencyGuide>[
      ...await EmergencyGuides.load('es'),
      ...await EmergencyGuides.load('en'),
    ];
    // 31 guías × 2 idiomas (25 originales + 6 de supervivencia 2026-07-09).
    expect(guides, hasLength(62));

    for (final guide in guides) {
      final media = EmergencyGuideMedia.forGuide(guide.id);
      expect(media.title.trim(), isNotEmpty, reason: guide.id);
      expect(media.scenePrompt.trim().length, greaterThan(180),
          reason: guide.id);
      expect(media.videoPrompt.trim().length, greaterThan(180),
          reason: guide.id);
      expect(media.animationKind.name, isNotEmpty, reason: guide.id);
      if (media.imageAssetPath != null) {
        expect(media.imageAssetPath, startsWith('assets/emergency_guides/images/'),
            reason: guide.id);
        expect(media.imageAltText.trim().length, greaterThan(32),
            reason: '${guide.id} debe tener alt text útil para accesibilidad');
      }
      expect(
          media.safetyNote.toLowerCase(),
          anyOf(contains('no sustituye'), contains('does not replace'),
              contains('contextual')),
          reason: '${guide.id} debe dejar claro que el visual es apoyo seguro');
      expect(media.scenePrompt.toLowerCase(), isNot(contains('gore')),
          reason: guide.id);
      expect(media.scenePrompt.toLowerCase(), isNot(contains('blood pool')),
          reason: guide.id);
    }
  });

  test(
      'guías médicas usan fotos contextuales, no demostraciones fotorealistas de técnica',
      () {
    for (final id in EmergencyGuideMedia.medicalTechniqueIds) {
      final media = EmergencyGuideMedia.forGuide(id);
      expect(media.visualPolicy, VisualPolicy.contextOnly, reason: id);
      expect(media.scenePrompt.toLowerCase(), contains('contextual'));
      expect(media.scenePrompt.toLowerCase(),
          isNot(contains('exact hand placement')));
      expect(media.scenePrompt.toLowerCase(),
          isNot(contains('clinical procedure demonstration')));
    }
  });
}
