// El modelo de IA activo, global a toda la app (chat general + especialistas).
// Lógica pura y sin IO: la UI le pasa qué está instalado, qué eligió el
// usuario y cuánta RAM hay libre, y decide qué .gguf cargar. También traduce
// un nombre de archivo .gguf a algo legible para el selector.
import 'agents/model_catalog.dart';
import '../depot/kiwix_catalog.dart';

/// Fracción de RAM libre que un modelo puede ocupar sin arriesgar un kill por
/// presión de memoria (mismo umbral que AgentRuntime).
const double _ramSafety = 0.8;

/// Tamaño conocido de un .gguf por nombre, o null si no está en ningún
/// catálogo (un modelo que el usuario metió a mano).
int? _knownBytes(String fileName) {
  for (final m in ModelCatalog.all) {
    if (m.fileName == fileName) return m.sizeBytes;
  }
  for (final m in curatedModels) {
    if (m.fileName == fileName) return m.approxBytes;
  }
  return null;
}

bool _fits(String fileName, int? freeRamBytes) {
  if (freeRamBytes == null) return true; // RAM desconocida: no bloquear.
  final bytes = _knownBytes(fileName);
  if (bytes == null) return true; // tamaño desconocido: confiar en el usuario.
  return bytes <= freeRamBytes * _ramSafety;
}

/// "Mejor" = mayor primero, entre los instalados de la cadena de especialistas
/// que además caben en RAM. Empareja el default con lo que ya usa el sistema.
String? _bestChainModel(List<String> installed, int? freeRamBytes) {
  // ModelCatalog.all va de mayor a menor (e4b → e2b → 3b → 1.5b → 1b → 0.5b).
  for (final m in ModelCatalog.all) {
    if (installed.contains(m.fileName) && _fits(m.fileName, freeRamBytes)) {
      return m.fileName;
    }
  }
  // Ningún modelo de la cadena cabe/está: cae a cualquier instalado que quepa.
  for (final f in installed) {
    if (_fits(f, freeRamBytes)) return f;
  }
  return installed.isEmpty ? null : installed.first;
}

/// Qué .gguf cargar dado lo instalado, la elección del usuario y la RAM libre.
/// - elegido instalado y cabe → elegido.
/// - si no → el mejor de la cadena instalado que quepa (Gemma 4 por defecto).
/// - nada instalado → null.
String? resolveActiveModel({
  required List<String> installed,
  required String? chosen,
  required int? freeRamBytes,
}) {
  if (chosen != null &&
      installed.contains(chosen) &&
      _fits(chosen, freeRamBytes)) {
    return chosen;
  }
  return _bestChainModel(installed, freeRamBytes);
}

/// Nombre legible de un .gguf para el selector: primero el catálogo de
/// Depósito, luego la cadena de especialistas, y si no está en ninguno, se
/// embellece el nombre del archivo (sin extensión, guiones→espacios).
String modelDisplayName(String fileName) {
  for (final m in curatedModels) {
    if (m.fileName == fileName) return m.name;
  }
  const chainNames = {
    'gemma-4-E4B-it-Q4_K_M.gguf': 'Gemma 4 E4B (especialista)',
    'gemma-4-E2B-it-Q4_K_M.gguf': 'Gemma 4 E2B (especialista)',
    'gemma-4-E2B-it-qat-UD-Q4_K_XL.gguf': 'Gemma 4 E2B QAT (especialista)',
    'Qwen3-1.7B-Q4_K_M.gguf': 'Qwen 3 1.7B',
    'qwen2.5-3b-instruct-q4_k_m.gguf': 'Qwen 2.5 3B',
    'qwen2.5-1.5b-instruct-q4_k_m.gguf': 'Qwen 2.5 1.5B',
    'google_gemma-3-1b-it-Q4_K_M.gguf': 'Gemma 3 1B',
    'qwen2.5-0.5b-instruct-q4_k_m.gguf': 'Qwen 2.5 0.5B (respaldo)',
  };
  final chain = chainNames[fileName];
  if (chain != null) return chain;
  var base = fileName;
  final dot = base.lastIndexOf('.gguf');
  if (dot > 0) base = base.substring(0, dot);
  return base.replaceAll(RegExp(r'[-_]+'), ' ').trim();
}
