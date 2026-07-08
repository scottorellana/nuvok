import 'package:flutter/material.dart';

/// Central visual tokens for Prepper Pad's emergency dark theme.
///
/// Keeping these colors named prevents visual drift across modules and makes
/// it obvious when a color is semantic (danger/caution/success) vs decorative.
abstract final class PrepperColors {
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
}
