import unittest

import translate_emergency_guides as translator


class NumericTokenParsingTest(unittest.TestCase):
    def test_unit_prefix_is_not_taken_from_a_word(self):
        self.assertEqual(translator._tokens(translator.NUMBER_RE, "1 mes"), ["1"])
        self.assertEqual(translator._tokens(translator.NUMBER_RE, "1 mês"), ["1"])
        self.assertEqual(translator._tokens(translator.NUMBER_RE, "5 mwa"), ["5"])

    def test_bare_number_is_preserved_next_to_japanese_text(self):
        self.assertEqual(translator._tokens(translator.NUMBER_RE, "1日"), ["1"])

    def test_units_are_preserved_before_japanese_particles(self):
        text = "200 Lの容器、15 min以内、1 mmの雨"
        self.assertEqual(
            translator._tokens(translator.NUMBER_RE, text),
            ["1 mm", "15 min", "200 L"],
        )

    def test_real_units_remain_atomic_tokens(self):
        text = "1 m, 10 m, 20°C, 48 h"
        self.assertEqual(
            translator._tokens(translator.NUMBER_RE, text),
            ["1 m", "10 m", "20°C", "48 h"],
        )

    def test_japanese_redundant_unit_glosses_are_removed(self):
        text = "24 h時間、30 min分、200 Lリットル、5%パーセント、30 cmセンチメートル、60 mメートル"
        self.assertEqual(
            translator.strip_redundant_unit_glosses(text, "ja"),
            "24 h、30 min、200 L、5%、30 cm、60 m",
        )

    def test_japanese_normalization_does_not_remove_normal_following_text(self):
        text = "24 h後、200 L容器"
        self.assertEqual(translator.strip_redundant_unit_glosses(text, "ja"), text)
        self.assertEqual(
            translator.strip_redundant_unit_glosses("24 h時間", "pt"),
            "24 h時間",
        )


if __name__ == "__main__":
    unittest.main()
