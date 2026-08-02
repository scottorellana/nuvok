// Cuándo Nuvok actúa SOLO para estirar la batería.
//
// En un apagón el teléfono es el único recurso y debe durar días. El ahorro
// existía, pero solo se activaba si el usuario lo encontraba y lo tocaba:
// alguien con 6% de batería, a oscuras y asustado, no navega menús.
//
// Reglas puras (sin IO) para poder verificarlas. Dos principios:
//  - Actuar solo cuando ayuda de verdad (batería crítica y sin cargador).
//  - No pelearse con la persona: si apagó el ahorro a mano, se respeta.

/// Por debajo de este porcentaje la app aplica el ahorro por su cuenta.
const int autoSaverThreshold = 10;

/// Umbral en el que la malla pasa a modo equilibrado (antes de lo crítico).
const int meshBalancedThreshold = 30;

bool shouldAutoEnableSaver({
  required int level,
  required bool charging,
  required bool alreadyOn,
  required bool userTurnedOff,
}) {
  if (level < 0) return false; // batería desconocida (escritorio sin batería)
  if (charging || alreadyOn || userTurnedOff) return false;
  return level <= autoSaverThreshold;
}

/// Cuánta radio de malla mantener.
///
/// `minimal` NO es apagado: en batería crítica se sigue ESCUCHANDO el SOS de
/// un vecino, que es justo para lo que existe la app. Apagar la malla entera
/// ahorraría más, pero convierte al teléfono en un ladrillo silencioso.
enum MeshPowerPlan { full, balanced, minimal }

MeshPowerPlan meshPlanFor({required int level, required bool charging}) {
  if (charging || level < 0) return MeshPowerPlan.full;
  if (level <= autoSaverThreshold) return MeshPowerPlan.minimal;
  if (level <= meshBalancedThreshold) return MeshPowerPlan.balanced;
  return MeshPowerPlan.full;
}
