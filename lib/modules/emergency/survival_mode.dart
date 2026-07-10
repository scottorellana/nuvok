// Modos de supervivencia: el usuario declara SU entorno (bosque, desierto,
// mar…) y toda la app se especializa — el paquete de guías del entorno se
// destaca y la IA prioriza técnicas de ESE lugar.
import '../../core/prepper_library.dart';

enum SurvivalMode {
  none,
  bosque,
  desierto,
  mar,
  montana,
  ciudad,
  rio,
  pantano,
  artico,
}

extension SurvivalModeInfo on SurvivalMode {
  String get emoji => switch (this) {
        SurvivalMode.none => '',
        SurvivalMode.bosque => '🌲',
        SurvivalMode.desierto => '🏜️',
        SurvivalMode.mar => '🌊',
        SurvivalMode.montana => '🏔️',
        SurvivalMode.ciudad => '🏙️',
        SurvivalMode.rio => '🌀',
        SurvivalMode.pantano => '🐊',
        SurvivalMode.artico => '❄️',
      };

  /// Clave i18n del nombre del modo (modeBosque, modeDesierto, …).
  String get nameKey =>
      'mode${name[0].toUpperCase()}${name.substring(1)}';

  /// Paquete completo escrito y con ilustraciones. Los no-listos igualmente
  /// muestran las guías generales etiquetadas para su entorno.
  bool get ready =>
      this == SurvivalMode.bosque || this == SurvivalMode.desierto;
}

SurvivalMode survivalModeFromSetting(String? name) {
  if (name == null) return SurvivalMode.none;
  for (final m in SurvivalMode.values) {
    if (m.name == name) return m;
  }
  return SurvivalMode.none;
}

/// Modo activo persistido (sobrevive reinicios — en una emergencia larga la
/// app debe recordar dónde estás).
class SurvivalModeStore {
  static SurvivalMode get active => survivalModeFromSetting(
      PrepperLibrary.instance.settings['survivalMode'] as String?);

  static Future<void> setActive(SurvivalMode m) async {
    await PrepperLibrary.instance
        .saveSetting('survivalMode', m == SurvivalMode.none ? null : m.name);
  }
}
