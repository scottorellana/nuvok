import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _languages = ['es', 'en', 'pt', 'fr', 'zh', 'ja', 'ht'];
const _guideIds = ['rcp_adulto', 'rcp_nino_bebe', 'atragantamiento'];
const _ahaSource = 'https://cpr.heart.org/en/resuscitation-science/cpr-and-ecc-guidelines';

String _readGuide(String language, String guideId) => File(
  'assets/emergency_guides/$language/$guideId.md',
).readAsStringSync();

void main() {
  group('AHA 2025 emergency guides', () {
    test('are available offline in every supported language', () {
      for (final language in _languages) {
        for (final guideId in _guideIds) {
          expect(
            File('assets/emergency_guides/$language/$guideId.md').existsSync(),
            isTrue,
            reason: '$guideId must exist for $language',
          );
        }
      }
    });

    test('identify AHA 2025 as the clinical source in every language', () {
      for (final language in _languages) {
        for (final guideId in _guideIds) {
          final guide = _readGuide(language, guideId);
          expect(guide, contains('AHA 2025'));
          expect(guide, contains(_ahaSource));
        }
      }
    });

    test('adult CPR preserves high-quality CPR constants in every language', () {
      for (final language in _languages) {
        final guide = _readGuide(language, 'rcp_adulto');
        expect(guide, contains('100–120'));
        expect(guide, contains('5–6 cm'));
        expect(guide, contains('30:2'));
        expect(guide, contains('10'));
      }
    });

    test('pediatric CPR preserves ratios, depths, and 2025 infant technique', () {
      const updatedInfantTechnique = {
        'es': 'base de una mano',
        'en': 'heel of one hand',
        'pt': 'base de uma mão',
        'fr': 'talon d’une main',
        'zh': '单手掌根',
        'ja': '片手の手掌基部',
        'ht': 'baz pla yon men',
      };

      for (final language in _languages) {
        final guide = _readGuide(language, 'rcp_nino_bebe');
        expect(guide, contains('100–120'));
        expect(guide, contains('30:2'));
        expect(guide, contains('15:2'));
        expect(guide, contains('4 cm'));
        expect(guide, contains('5 cm'));
        expect(guide.toLowerCase(), contains(updatedInfantTechnique[language]));
      }

      final spanish = _readGuide('es', 'rcp_nino_bebe').toLowerCase();
      final english = _readGuide('en', 'rcp_nino_bebe').toLowerCase();
      expect(spanish, isNot(contains('da 5 ventilaciones iniciales')));
      expect(spanish, isNot(contains('usa la técnica de 2 dedos')));
      expect(english, isNot(contains('give 5 initial rescue breaths')));
      expect(english, isNot(contains('use the 2-finger technique')));
    });

    test('severe choking uses the 2025 sequence in every language', () {
      const backBlows = {
        'es': '5 golpes en la espalda',
        'en': '5 back blows',
        'pt': '5 golpes nas costas',
        'fr': '5 claques dans le dos',
        'zh': '5 次背部拍击',
        'ja': '背部叩打を5回',
        'ht': '5 frap nan do',
      };
      const infantChestTechnique = {
        'es': 'base de una mano',
        'en': 'heel of one hand',
        'pt': 'base de uma mão',
        'fr': 'talon d’une main',
        'zh': '单手掌根',
        'ja': '片手の手掌基部',
        'ht': 'baz pla yon men',
      };

      for (final language in _languages) {
        final guide = _readGuide(language, 'atragantamiento');
        expect(guide, contains(backBlows[language]!));
        expect(guide.toLowerCase(), contains(infantChestTechnique[language]));
      }

      final spanish = _readGuide('es', 'atragantamiento').toLowerCase();
      final english = _readGuide('en', 'atragantamiento').toLowerCase();
      expect(spanish, contains('no hagas un barrido a ciegas'));
      expect(english, contains('do not perform a blind finger sweep'));
    });
  });
}
