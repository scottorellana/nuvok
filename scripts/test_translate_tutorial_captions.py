import unittest
from unittest import mock

import translate_tutorial_captions as translator


class TranslateTutorialCaptionsTest(unittest.TestCase):
    def setUp(self):
        self.source = '''
const tutorials = <String, EmergencyGuideTutorial>{
  "agua": EmergencyGuideTutorial(
    assetPath: "assets/agua.png",
    steps: [
      EmergencyGuideTutorialStep(
        number: 1,
        captionEs: "Hierve 1 minuto",
        captionEn: "Boil for 1 minute",
      ),
    ],
  ),
};
'''

    def test_extracts_slug_number_and_exact_captions(self):
        rows = translator.parse_caption_pairs(self.source)
        self.assertEqual(
            [(row.key, row.number, row.es, row.en) for row in rows],
            [("agua:1", 1, "Hierve 1 minuto", "Boil for 1 minute")],
        )

    def test_rewrites_step_with_all_seven_caption_keys(self):
        translations = {
            "agua:1": {
                "pt": "Ferva por 1 minuto",
                "fr": "Faites bouillir pendant 1 minute",
                "zh": "煮沸1分钟",
                "ja": "1分間沸騰させる",
                "ht": "Bouyi pandan 1 minit",
            }
        }
        rewritten = translator.rewrite_caption_pairs(self.source, translations)
        for language in ("es", "en", "pt", "fr", "zh", "ja", "ht"):
            self.assertIn(f'"{language}":', rewritten)
        self.assertNotIn("captionEs:", rewritten)
        self.assertNotIn("captionEn:", rewritten)
        self.assertIn('"es": "Hierve 1 minuto"', rewritten)
        self.assertIn('"zh": "煮沸1分钟"', rewritten)

    def test_recognizes_a_fully_localized_registry(self):
        translations = {
            "agua:1": {
                language: f"{language} caption 1"
                for language in translator.TARGET_LANGUAGES
            }
        }
        rewritten = translator.rewrite_caption_pairs(self.source, translations)
        self.assertTrue(translator.is_fully_localized_registry(rewritten, expected_steps=1))
        self.assertFalse(translator.is_fully_localized_registry(rewritten, expected_steps=2))

    def test_rewrite_rejects_missing_translation(self):
        with self.assertRaisesRegex(ValueError, "missing translations"):
            translator.rewrite_caption_pairs(self.source, {})

    def test_dart_string_escapes_interpolation(self):
        self.assertEqual(translator.dart_string("Costo $5"), '"Costo \\$5"')

    def test_masks_and_restores_numeric_literals(self):
        row = translator.CaptionPair(
            slug="calor",
            number=1,
            es="De 10 a 16 h: descansa",
            en="From 10 to 16 h: rest",
        )
        masked = translator.mask_caption_pair(row)
        self.assertEqual(masked["es"], "De __KEEP_NUM_0__ a __KEEP_NUM_1__ h: descansa")
        self.assertEqual(masked["en"], "From __KEEP_NUM_0__ to __KEEP_NUM_1__ h: rest")
        restored = translator.restore_numeric_literals(
            row,
            {language: "保持__KEEP_NUM_0__至__KEEP_NUM_1__小时" for language in translator.TARGET_LANGUAGES},
        )
        self.assertEqual(restored["zh"], "保持10至16小时")

    def test_restore_rejects_a_missing_numeric_placeholder(self):
        row = translator.CaptionPair("agua", 3, "Usa 2 gotas", "Use 2 drops")
        with self.assertRaisesRegex(ValueError, "missing numeric placeholder"):
            translator.restore_numeric_literals(
                row,
                {language: "使用两滴" for language in translator.TARGET_LANGUAGES},
            )

    def test_masks_standardized_unit_with_its_number(self):
        row = translator.CaptionPair(
            "medicacion",
            1,
            "Administra 5 mg",
            "Administer 5 mg",
        )
        masked = translator.mask_caption_pair(row)
        self.assertEqual(masked["es"], "Administra __KEEP_NUM_0__")
        restored = translator.restore_numeric_literals(
            row,
            {
                language: "Administrar __KEEP_NUM_0__"
                for language in translator.TARGET_LANGUAGES
            },
        )
        self.assertTrue(all(value.endswith("5 mg") for value in restored.values()))

    def test_does_not_treat_start_of_unit_word_as_a_unit_symbol(self):
        self.assertEqual(translator._numeric_tokens("Enfría 20 minutos"), ["20"])
        self.assertEqual(translator._numeric_tokens("Mantén 20 m"), ["20 m"])

    def test_negated_caption_requires_an_immutable_anchor(self):
        row = translator.CaptionPair(
            "medicacion",
            2,
            "No administres medicamentos",
            "Do not administer medication",
        )
        masked = translator.mask_caption_pair(row)
        self.assertTrue(masked["es"].endswith("__KEEP_NEG__"))
        restored = translator.restore_numeric_literals(
            row,
            {
                language: "Negación traducida __KEEP_NEG__"
                for language in translator.TARGET_LANGUAGES
            },
        )
        self.assertTrue(
            all("__KEEP_NEG__" not in value for value in restored.values())
        )
        with self.assertRaisesRegex(ValueError, "missing negation anchor"):
            translator.restore_numeric_literals(
                row,
                {
                    language: "Traducción positiva"
                    for language in translator.TARGET_LANGUAGES
                },
            )

    def test_cjk_adjacent_ascii_numbers_remain_detectable(self):
        row = translator.CaptionPair(
            "calor",
            1,
            "Descansa de 10 a 16 h",
            "Rest from 10 to 16 h",
        )
        translated = {
            "pt": "Descanse das 10 às 16 h",
            "fr": "Reposez-vous de 10 à 16 h",
            "zh": "在10至16小时休息",
            "ja": "10時から16時まで休む",
            "ht": "Repoze soti 10 rive 16 h",
        }
        self.assertEqual(translator.validate_caption_translation(row, translated), [])

    def test_translate_batch_restores_numeric_literals_before_validation(self):
        row = translator.CaptionPair(
            slug="calor",
            number=1,
            es="De 10 a 16 h: descansa",
            en="From 10 to 16 h: rest",
        )
        response = {
            row.key: {
                language: "保持__KEEP_NUM_0__至__KEEP_NUM_1__小时"
                for language in translator.TARGET_LANGUAGES
            }
        }
        with mock.patch.object(translator, "request_batch", return_value=response):
            translated = translator.translate_batch([row])
        self.assertEqual(translated[row.key]["zh"], "保持10至16小时")

    def test_translate_resilient_batch_splits_a_cross_contaminated_batch(self):
        rows = [
            translator.CaptionPair("artico", 1, "Derrite nieve", "Melt snow"),
            translator.CaptionPair("artico", 2, "Hielo rinde doble", "Ice yields double"),
        ]
        translations = {
            row.key: {
                language: f"traducido {row.number}"
                for language in translator.TARGET_LANGUAGES
            }
            for row in rows
        }
        with mock.patch.object(
            translator,
            "translate_batch",
            side_effect=[
                RuntimeError("cross-contaminated batch"),
                {rows[0].key: translations[rows[0].key]},
                {rows[1].key: translations[rows[1].key]},
            ],
        ) as translate:
            result = translator.translate_resilient_batch(rows)
        self.assertEqual(result, translations)
        self.assertEqual(translate.call_count, 3)


if __name__ == "__main__":
    unittest.main()
