// ¿Este Nuvok funciona si hoy se cae todo?
//
// Alguien compra la app, la abre una vez, ve que tiene guías y la cierra. Seis
// meses después hay un apagón de tres días y descubre que nunca descargó el
// modelo de IA, que no tiene mapas de su ciudad y que el Bluetooth está
// apagado. Descubrirlo ESE día es descubrirlo tarde.
//
// Lógica pura y sin IO: entra el inventario, sale el diagnóstico. La UI solo
// pinta lo que esto decide.

/// Qué le falta a este equipo, en el orden en que conviene resolverlo.
enum ReadinessArea {
  /// Especialistas de IA: sin modelo instalado no hay ninguno.
  ai,

  /// Mapas offline: sin ellos no sabes dónde estás ni cómo salir.
  maps,

  /// Biblioteca (Wikipedia y libros): lo que no cabe en las guías.
  library,

  /// Malla: identidad + radio. Es lo único que te conecta con los demás.
  mesh,

  /// Batería: en un apagón es literalmente el recurso que se agota.
  battery,

  /// Permiso de ubicación. Sin él el SOS sale sin coordenadas: te oyen pero
  /// no saben dónde estás, y nadie pide ese permiso hasta el día que hace
  /// falta — es decir, tarde.
  location,
}

class ReadinessItem {
  const ReadinessItem(this.area, {required this.ok, required this.essential});

  final ReadinessArea area;
  final bool ok;

  /// Si falta, se pierde algo que ninguna otra parte de la app suple.
  final bool essential;
}

enum ReadinessLevel { ready, partial, notReady }

class ReadinessReport {
  const ReadinessReport(this.items);
  final List<ReadinessItem> items;

  Iterable<ReadinessItem> get missing => items.where((i) => !i.ok);

  ReadinessLevel get level {
    if (missing.isEmpty) return ReadinessLevel.ready;
    if (missing.any((i) => i.essential)) return ReadinessLevel.notReady;
    return ReadinessLevel.partial;
  }

  /// 0-100. Sirve para una barra, no para presumir: lo que importa es la
  /// lista de lo que falta, no el número.
  int get score {
    if (items.isEmpty) return 100;
    final ok = items.where((i) => i.ok).length;
    return (ok * 100 / items.length).round();
  }
}

/// Por debajo de esto la batería deja de ser un detalle. No es alarmismo: con
/// la red caída el teléfono es linterna, radio, mapa y botiquín a la vez.
const int lowBatteryForReadiness = 40;

/// Diagnóstico del equipo.
///
/// Las guías de emergencia NO son un ítem: van empaquetadas en la app y están
/// siempre. Un indicador que siempre dice "sí" no informa de nada.
ReadinessReport assessReadiness({
  required int aiModels,
  required int offlineMaps,
  required int libraryFiles,
  required bool meshIdentity,
  required bool meshRadioAvailable,
  required int batteryLevel,
  required bool locationGranted,
}) {
  return ReadinessReport([
    // La malla es lo único que no tiene sustituto: sin ella estás solo,
    // por muchas guías que tengas.
    ReadinessItem(ReadinessArea.mesh,
        ok: meshIdentity && meshRadioAvailable, essential: true),
    // Esencial junto con la malla: de nada sirve que te oigan si el SOS sale
    // sin un solo dato de dónde estás.
    ReadinessItem(ReadinessArea.location,
        ok: locationGranted, essential: true),
    ReadinessItem(ReadinessArea.ai, ok: aiModels > 0, essential: false),
    ReadinessItem(ReadinessArea.maps, ok: offlineMaps > 0, essential: false),
    ReadinessItem(ReadinessArea.library,
        ok: libraryFiles > 0, essential: false),
    // Nivel desconocido (-1) no se castiga: mejor callar que asustar con un
    // dato que no se pudo leer.
    ReadinessItem(ReadinessArea.battery,
        ok: batteryLevel < 0 || batteryLevel >= lowBatteryForReadiness,
        essential: false),
  ]);
}
