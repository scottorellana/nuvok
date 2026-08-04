// La lógica pura detrás de "Prepara tu Nuvok" (primer arranque).
//
// El instalador llega ligero (~300 MB): sin modelo de IA, sin mapas y sin
// enciclopedia. Este módulo decide QUÉ proponer descargar — sin que el
// usuario tenga que saber qué es un modelo ni cuánta RAM tiene — y arma las
// peticiones de descarga. Sin IO ni Platform: todo entra por parámetros para
// poder verificarlo en tests.
import '../ai/agents/model_catalog.dart';

/// Fracción de la RAM libre que un modelo puede ocupar sin arriesgar un kill
/// por presión de memoria. MISMO umbral que usa el runtime al cargar
/// (active_model/_ramSafety): proponer con un criterio y cargar con otro
/// haría descargar gigas que luego no se pueden usar.
const double starterRamSafety = 0.8;

/// Tope de tamaño cuando NO se pudo medir la RAM libre.
///
/// 1,5 GB cabe holgado en cualquier teléfono que arranque la app, así que la
/// descarga no se tira a la basura. Es una apuesta conservadora a propósito:
/// quien tenga más RAM puede subir de modelo desde Depósito en cuanto la app
/// mida su equipo; quien tenga menos no habría podido usar nada mayor.
const int unknownRamMaxBytes = 1500 * 1024 * 1024;

/// Qué modelo proponer para descargar en el primer arranque.
///
/// Camina la cadena de la plataforma (escritorio arranca en E4B, teléfono en
/// E2B) y devuelve el primero que cabe en la RAM libre medida. Nunca null:
/// sin modelo los especialistas quedan muertos para siempre, así que en el
/// peor caso propone el 0.5B de respaldo.
///
/// Con RAM desconocida propone un escalón bajo el default de la plataforma:
/// sugerir 3.4 GB a ciegas puede tirar la descarga entera a la basura.
ModelEntry resolveStarterModel({
  required bool isDesktop,
  required int? freeRamBytes,
}) {
  final chain = ModelCatalog.chainFrom(
      ModelCatalog.resolveClass(ModelClass.general, isDesktop: isDesktop));
  if (freeRamBytes == null) {
    // Sin medición, proponer por TAMAÑO, no por posición en la cadena.
    //
    // Antes esto devolvía chain[1] ("un escalón bajo el de la plataforma"),
    // que dejó de significar lo que decía en cuanto la cadena cambió: al
    // entrar el E2B-QAT por delante del E2B normal, ese "escalón abajo" pasó
    // a ser un modelo MÁS grande que el punto de partida. Y proponer gigas de
    // más a ciegas es la peor forma de gastar la única conexión que quizá
    // tenga esa persona.
    for (final m in chain) {
      if (m.sizeBytes <= unknownRamMaxBytes) return m;
    }
    return chain.last;
  }
  for (final m in chain) {
    if (m.sizeBytes <= freeRamBytes * starterRamSafety) return m;
  }
  return chain.last;
}

/// Una descarga que la página de arranque encola. `relativeDir` es la
/// subcarpeta de la biblioteca Nuvok/ ('models', 'zim'): la página la
/// resuelve a ruta absoluta; los tests la verifican sin tocar disco.
class StarterDownloadRequest {
  const StarterDownloadRequest({
    required this.url,
    required this.relativeDir,
    required this.fileName,
    this.totalBytes,
    this.sha256Hex,
  });

  final String url;
  final String relativeDir;
  final String fileName;
  final int? totalBytes;
  final String? sha256Hex;
}

bool _isRealSha(String sha) => RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha);

/// Arma las peticiones de "Descargar todo": el modelo elegido y, si el
/// catálogo en vivo la resolvió, la Wikipedia médica. El mapa NO va aquí:
/// se instala recortando el build de Protomaps, un flujo con su propia
/// pantalla (Mapas), no una descarga directa.
List<StarterDownloadRequest> starterDownloadRequests({
  required ModelEntry model,
  required String? wikiUrl,
  required int? wikiBytes,
}) {
  return [
    StarterDownloadRequest(
      url: model.url,
      relativeDir: 'models',
      fileName: model.fileName,
      totalBytes: model.sizeBytes,
      // 'TO_FILL_ON_UPLOAD' marca hashes aún no publicados: se pasa null para
      // no rechazar la descarga contra un checksum placeholder.
      sha256Hex: _isRealSha(model.sha256) ? model.sha256 : null,
    ),
    if (wikiUrl != null)
      StarterDownloadRequest(
        url: wikiUrl,
        relativeDir: 'zim',
        fileName: Uri.parse(wikiUrl).pathSegments.last,
        totalBytes: wikiBytes,
      ),
  ];
}
