import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Central visual tokens for Nuvok's emergency dark theme.
///
/// Keeping these colors named prevents visual drift across modules and makes
/// it obvious when a color is semantic (danger/caution/success) vs decorative.
abstract final class NuvokColors {
  static const background = Color(0xFF14170F);
  static const card = Color(0xFF1A1F12);
  static const cardElevated = Color(0xFF222818);
  static const text = Color(0xFFE8F0D8);
  static const dimText = Color(0xFF8A9070);

  static const olive = Color(0xFF8C9E5E);
  static const oliveDark = Color(0xFF5E6F3C);
  static const emergency = Color(0xFFEF5350);
  static const emergencyDark = Color(0xFFC62828);
  static const emergencyDeep = Color(0xFFB71C1C);
  static const caution = Color(0xFFFFAB40);
  static const cautionSurface = Color(0xFF2A2018);
  static const safe = Color(0xFF9CCC65);
  static const info = Color(0xFF64B5F6);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  /// Color de texto/icono legible sobre [background].
  ///
  /// Los botones del modo pánico usaban blanco fijo: sobre `caution`
  /// (naranja) eso da 1.87:1 — ilegible bajo sol directo o con la pantalla
  /// atenuada al mínimo para ahorrar batería, que es justo cuando se usan.
  /// Negro sobre naranja da 11.2:1.
  static Color onColor(Color background) {
    // Luminancia relativa WCAG.
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    final l = 0.2126 * ch(background.r) +
        0.7152 * ch(background.g) +
        0.0722 * ch(background.b);
    // Punto de corte donde el negro empieza a contrastar mejor que el blanco.
    return l > 0.18 ? black : white;
  }
}
