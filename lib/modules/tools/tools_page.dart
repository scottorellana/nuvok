// Tools page — quick survival tools accessible from the nav rail.
// Groups flashlight, compass, and future tools in one place.
import 'package:flutter/material.dart';

import 'compass.dart';
import 'flashlight.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Herramientas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
