// ¿Cabe lo que el usuario está a punto de descargar?
//
// Nuvok ofrece paquetes de hasta 3.4 GB (Gemma 4 E2B) en teléfonos que suelen
// estar llenos. Sin esta comprobación la descarga corría 40 minutos y moría
// sin espacio: datos móviles quemados y, peor, un usuario convencido de que su
// kit de emergencia estaba listo cuando no lo estaba.
//
// La decisión es PURA (sin IO) para poder verificarla; quien consulta el disco
// es la UI, que pasa los bytes libres medidos.
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'nuvok_library.dart' show humanSize;

const _channel = MethodChannel('nuvok/bundled_assets');

/// Bytes libres en el volumen de [path], o null si la plataforma no sabe
/// decirlo (Windows/Linux, o cualquier fallo). Nunca lanza: no poder medir
/// jamás debe impedir que alguien prepare su kit.
Future<int?> freeSpaceBytes(String path) async {
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) return null;
  try {
    final v = await _channel.invokeMethod<Object?>('freeSpace', {'path': path});
    return (v as num?)?.toInt();
  } catch (_) {
    return null;
  }
}

/// Margen que se le deja SIEMPRE al dispositivo. Un teléfono a cero no puede
/// actualizar el sistema, sacar una foto de la escena ni guardar una nota.
const int minFreeReserveBytes = 500 * 1024 * 1024;

class SpaceVerdict {
  const SpaceVerdict({
    required this.fits,
    required this.tight,
    required this.unknown,
    required this.missingBytes,
  });

  /// ¿Hay espacio para completar la descarga?
  final bool fits;

  /// Cabe, pero dejaría el equipo por debajo de la reserva mínima.
  final bool tight;

  /// La plataforma no supo decir cuánto espacio hay: no se bloquea nada.
  final bool unknown;

  /// Cuántos bytes faltan (0 si cabe).
  final int missingBytes;

  /// Texto listo para mostrar, en unidades que una persona entiende.
  String get shortfallText =>
      missingBytes <= 0 ? '' : humanSize(missingBytes);
}

/// Decide si una descarga cabe. [alreadyBytes] es lo ya descargado (un .part
/// que se va a reanudar): solo se exige el resto.
SpaceVerdict checkSpaceFor({
  required int needBytes,
  required int? freeBytes,
  int alreadyBytes = 0,
}) {
  final remaining = needBytes - alreadyBytes;
  if (freeBytes == null) {
    return const SpaceVerdict(
        fits: true, tight: false, unknown: true, missingBytes: 0);
  }
  final fits = freeBytes >= remaining;
  return SpaceVerdict(
    fits: fits,
    tight: fits && freeBytes - remaining < minFreeReserveBytes,
    unknown: false,
    missingBytes: fits ? 0 : remaining - freeBytes,
  );
}
