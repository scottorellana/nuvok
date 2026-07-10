// Calculadoras de emergencia con fórmulas estándar OMS. Puras y testeadas:
// aquí un error de cálculo hace daño real, por eso cada fórmula cita su
// fuente y rechaza entradas fuera de rango en vez de extrapolar.
//
// Fuentes:
//  - Paracetamol pediátrico: 10-15 mg/kg por dosis, cada 6-8 h, máx 4/día
//    (OMS, formulario pediátrico).
//  - Ibuprofeno pediátrico: 5-10 mg/kg por dosis, cada 8 h, máx 3/día;
//    NO en menores de 3 meses (~5 kg).
//  - SRO casero: 1 L de agua segura + 6 cucharaditas rasas de azúcar +
//    1/2 cucharadita rasa de sal (OMS/UNICEF, receta doméstica).
//  - Cloro: lejía doméstica al 5% → 2 gotas por litro (agua clara), doble en
//    agua turbia, reposar 30 min (OMS/CDC guía de tratamiento doméstico).
class PediatricDose {
  const PediatricDose({
    required this.minMg,
    required this.maxMg,
    required this.maxDosesPerDay,
    required this.intervalHours,
  });
  final int minMg;
  final int maxMg;
  final int maxDosesPerDay;
  final int intervalHours;
}

class OrsRecipe {
  const OrsRecipe({required this.sugarTsp, required this.saltTsp});

  /// Cucharaditas RASAS de azúcar.
  final double sugarTsp;

  /// Cucharaditas RASAS de sal.
  final double saltTsp;
}

class EmergencyCalculators {
  /// Paracetamol pediátrico por peso: 10-15 mg/kg por dosis, máx 4/día.
  static PediatricDose paracetamolDose(double weightKg) {
    if (weightKg <= 0 || weightKg > 150) {
      throw ArgumentError('peso fuera de rango');
    }
    return PediatricDose(
      minMg: (weightKg * 10).round(),
      maxMg: (weightKg * 15).round(),
      maxDosesPerDay: 4,
      intervalHours: 6,
    );
  }

  /// Ibuprofeno pediátrico por peso: 5-10 mg/kg por dosis, máx 3/día.
  /// Bloqueado bajo ~5 kg (menores de 3 meses: NUNCA sin médico).
  static PediatricDose ibuprofenDose(double weightKg) {
    if (weightKg < 5 || weightKg > 150) {
      throw ArgumentError('peso fuera de rango para ibuprofeno');
    }
    return PediatricDose(
      minMg: (weightKg * 5).round(),
      maxMg: (weightKg * 10).round(),
      maxDosesPerDay: 3,
      intervalHours: 8,
    );
  }

  /// Receta casera de suero oral OMS escalada a [liters] de agua SEGURA.
  static OrsRecipe oralRehydration(double liters) {
    if (liters <= 0 || liters > 20) throw ArgumentError('litros fuera de rango');
    return OrsRecipe(sugarTsp: 6 * liters, saltTsp: 0.5 * liters);
  }

  /// Gotas de lejía para purificar [liters] de agua. Base OMS/CDC:
  /// 2 gotas/L con lejía al 5%; se escala inverso a la concentración y se
  /// duplica con agua turbia. Reposar 30 minutos antes de beber.
  static int chlorineDrops({
    required double liters,
    required double bleachPercent,
    bool cloudy = false,
  }) {
    if (liters <= 0 || liters > 100) throw ArgumentError('litros fuera de rango');
    if (bleachPercent <= 0 || bleachPercent > 12) {
      throw ArgumentError('la lejía doméstica va de ~1% a 12%');
    }
    final base = 2 * (5 / bleachPercent) * liters;
    final drops = cloudy ? base * 2 : base;
    return drops.ceil();
  }
}
