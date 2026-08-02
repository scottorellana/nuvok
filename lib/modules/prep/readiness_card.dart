// Tarjeta "¿está listo este Nuvok?" — el diagnóstico del EQUIPO, junto a la
// checklist que ya cubre lo físico (agua, comida, botiquín).
//
// Lee el inventario real de la biblioteca y la malla; la decisión vive en
// readiness.dart, que es lógica pura y testeable.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import '../../core/nuvok_colors.dart';
import '../../core/nuvok_library.dart';
import '../maps/location_service.dart';
import '../mesh/mesh_service.dart';
import '../tools/battery_saver.dart';
import 'readiness.dart';

class ReadinessCard extends StatefulWidget {
  const ReadinessCard({super.key, this.onFix});

  /// Lleva al usuario a donde puede resolver [area]. Sin esto la tarjeta solo
  /// da malas noticias y ninguna salida.
  final void Function(ReadinessArea area)? onFix;

  @override
  State<ReadinessCard> createState() => _ReadinessCardState();
}

class _ReadinessCardState extends State<ReadinessCard> {
  ReadinessReport? _report;

  /// Último valor conocido del permiso de ubicación; null = aún sin saber.
  bool? _locationGranted;

  @override
  void initState() {
    super.initState();
    _assess();
    BatterySaverController.instance.addListener(_onBattery);
  }

  @override
  void dispose() {
    BatterySaverController.instance.removeListener(_onBattery);
    super.dispose();
  }

  void _onBattery() => _assess();

  void _assess() {
    // TODO el inventario va dentro del try, incluido llegar al singleton:
    // NuvokLibrary.instance lanza si init() no ha terminado, y un StateError
    // en initState no tumba la tarjeta, tumba la pantalla de Preparación
    // entera. Un diagnóstico que se cae es peor que no tener diagnóstico.
    var ai = 0, maps = 0, books = 0;
    var identity = false, radio = false, battery = -1, location = false;
    try {
      final lib = NuvokLibrary.instance;
      ai = lib.listModels().length;
      maps = lib.listMaps().length;
      books = lib.listZims().length;
    } catch (_) {
      // Biblioteca aún no lista: cuenta como "no instalado", que es
      // exactamente lo que el usuario tiene ahora mismo.
    }
    try {
      final mesh = MeshService.instance;
      identity = mesh.hasIdentity;
      // La radio cuenta como disponible si algún transporte está vivo: en
      // escritorio no hay BLE pero sí LAN, y eso también conecta.
      radio = mesh.anyTransportAvailable;
    } catch (_) {}
    try {
      battery = BatterySaverController.instance.batteryLevel;
    } catch (_) {}

    // El permiso se consulta a la plataforma y eso es asíncrono. La tarjeta
    // NO espera a ese dato para pintarse: si el canal nativo tarda o no
    // responde, un diagnóstico invisible no diagnostica nada. Mientras no se
    // sepa se asume concedido — misma política que la batería desconocida:
    // callar antes que acusar de algo que no hemos comprobado.
    location = _locationGranted ?? true;
    unawaited(LocationService.hasPermission().then((granted) {
      if (!mounted || granted == _locationGranted) return;
      _locationGranted = granted;
      _assess();
    }).catchError((_) {}));

    final report = assessReadiness(
      aiModels: ai,
      offlineMaps: maps,
      libraryFiles: books,
      meshIdentity: identity,
      meshRadioAvailable: radio,
      batteryLevel: battery,
      locationGranted: location,
    );
    if (mounted) setState(() => _report = report);
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    if (r == null) return const SizedBox.shrink();
    final es = LocaleService.instance.language.code == 'es';
    final (color, title) = switch (r.level) {
      ReadinessLevel.ready => (
          NuvokColors.safe,
          es ? 'Tu Nuvok está listo' : 'Your Nuvok is ready',
        ),
      ReadinessLevel.partial => (
          NuvokColors.caution,
          es ? 'Casi listo' : 'Almost ready',
        ),
      ReadinessLevel.notReady => (
          NuvokColors.emergency,
          es ? 'Aún no está listo' : 'Not ready yet',
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  r.level == ReadinessLevel.ready
                      ? Icons.verified
                      : Icons.warning_amber_rounded,
                  color: color,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        es
                            ? 'Si hoy se cae todo, esto es lo que tienes'
                            : 'If everything goes down today, this is what you have',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
                Text('${r.score}%',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ],
            ),
            for (final item in r.missing) ...[
              const SizedBox(height: 10),
              _MissingRow(
                area: item.area,
                essential: item.essential,
                es: es,
                onFix: widget.onFix,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingRow extends StatelessWidget {
  const _MissingRow({
    required this.area,
    required this.essential,
    required this.es,
    this.onFix,
  });

  final ReadinessArea area;
  final bool essential;
  final bool es;
  final void Function(ReadinessArea)? onFix;

  /// Qué se pierde exactamente. No "falta X": lo que el usuario necesita
  /// saber es qué NO va a poder hacer el día del apagón.
  (IconData, String) get _what => switch (area) {
        ReadinessArea.mesh => (
            Icons.cell_tower,
            es
                ? 'Sin malla: nadie puede encontrarte ni oír tu SOS'
                : 'No mesh: nobody can find you or hear your SOS',
          ),
        ReadinessArea.ai => (
            Icons.psychology,
            es
                ? 'Sin modelo de IA: los especialistas no responden'
                : 'No AI model: the specialists cannot answer',
          ),
        ReadinessArea.maps => (
            Icons.map,
            es
                ? 'Sin mapas: no sabrás dónde estás ni cómo salir'
                : 'No maps: you will not know where you are or how to get out',
          ),
        ReadinessArea.library => (
            Icons.menu_book,
            es
                ? 'Sin biblioteca: solo tendrás las guías de emergencia'
                : 'No library: only the emergency guides',
          ),
        ReadinessArea.location => (
            Icons.location_off,
            es
                ? 'Sin permiso de ubicación: tu SOS sale sin decir dónde estás'
                : 'No location permission: your SOS goes out without saying where you are',
          ),
        ReadinessArea.battery => (
            Icons.battery_alert,
            es
                ? 'Batería baja: cárgala antes de necesitarla'
                : 'Low battery: charge it before you need it',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, text) = _what;
    final color =
        essential ? NuvokColors.emergency : Theme.of(context).hintColor;
    return InkWell(
      onTap: onFix == null ? null : () => onFix!(area),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
            if (onFix != null)
              Icon(Icons.chevron_right,
                  size: 20, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }
}
