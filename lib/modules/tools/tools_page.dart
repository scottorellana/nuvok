// Tools page — quick survival tools accessible from the nav rail.
// Groups battery saver, flashlight, compass, whistle, GPS track, and future tools.
import 'package:flutter/material.dart';

import 'battery_saver.dart';
import 'compass.dart';
import 'flashlight.dart';
import 'whistle.dart';
import '../maps/gpx_recorder.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Herramientas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Battery saver — shows the REAL battery level and opens the saver.
          ListenableBuilder(
            listenable: BatterySaverController.instance,
            builder: (context, _) {
              final b = BatterySaverController.instance;
              final low = b.batteryKnown && b.batteryLevel <= 20;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            b.isCharging
                                ? Icons.battery_charging_full
                                : Icons.battery_saver,
                            size: 32,
                            color: low ? Colors.red : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              b.batteryKnown
                                  ? 'Batería: ${b.batteryLevel}%'
                                      '${b.isCharging ? ' · cargando' : ''}'
                                  : 'Ahorro de batería',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const BatterySaverPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.battery_saver),
                            label: const Text('Abrir'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        low
                            ? '⚠️ Batería baja. Activa el ahorro para durar más.'
                            : 'Maximiza la autonomía en una emergencia: reduce '
                                'consumo y desactiva servicios no esenciales.',
                        style: TextStyle(
                            color:
                                low ? Colors.red : Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Whistle - NEW
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sports_score,
                          size: 32, color: Colors.red),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Silbato de Emergencia',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const WhistleScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Activar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Silbato digital de alta frecuencia (3kHz) audible a larga '
                    'distancia. Incluye modo pulsado y flash de pantalla.',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // GPS Track Recorder
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route, size: 32, color: Colors.green),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'GPS Track + GPX',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const GpxRecorderWidget(),
                  const SizedBox(height: 8),
                  Text(
                    'Graba tu ruta y expórtala como GPX 1.1 para usarla '
                    'en otros mapas o dispositivos Garmin.',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Flashlight
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flashlight_on, size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Linterna / SOS luminoso',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FlashlightScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.flash_on),
                        label: const Text('Abrir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ilumina con el flash de la cámara. Activa SOS para '
                    'señal luminosa en código Morse (...---...).',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Compass
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.explore, size: 32),
                      const SizedBox(width: 12),
                      const Text(
                        'Brújula',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const CompassWidget(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Tip
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Consejo: calibra la brújula moviendo el dispositivo '
                      'en forma de 8 antes de usarla. En emergencias, la '
                      'linterna en modo SOS es visible a kilómetros en la '
                      'oscuridad.',
                      style: TextStyle(
                          color: Theme.of(context).hintColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
