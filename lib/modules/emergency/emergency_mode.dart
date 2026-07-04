// Emergency Mode — maximizes tablet utility during active emergencies.
// Keeps screen on, provides quick access to all emergency tools,
// and displays immediate action checklist.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class EmergencyModeController extends ChangeNotifier {
  EmergencyModeController._();
  static final EmergencyModeController instance = EmergencyModeController._();

  bool _active = false;
  bool get active => _active;

  int _step = 0;
  int get step => _step;

  Timer? _timer;

  final List<EmergencyStep> _steps = [
    EmergencyStep(
      title: 'Evalúa tu seguridad',
      description: '¿Estás fuera de peligro inmediato?',
      icon: Icons.warning_amber,
    ),
    EmergencyStep(
      title: 'Llama emergencias',
      description: 'Usa el directorio para llamar al 911 /本国緊急番号',
      icon: Icons.phone,
    ),
    EmergencyStep(
      title: 'Activa alarma SOS',
      description: 'Envía señal de emergencia a tus contactos mesh',
      icon: Icons.sos,
    ),
    EmergencyStep(
      title: 'Verifica ubicación',
      description: 'Comparte tu ubicación con rescuers',
      icon: Icons.location_on,
    ),
    EmergencyStep(
      title: 'Activa linterna',
      description: 'Hazte visible en la oscuridad',
      icon: Icons.flashlight_on,
    ),
    EmergencyStep(
      title: 'Prepara botiquín',
      description: 'Ten a mano materiales de primeros auxilios',
      icon: Icons.medical_services,
    ),
    EmergencyStep(
      title: 'Agua y comida',
      description: 'Asegura reservas de agua potable',
      icon: Icons.water_drop,
    ),
    EmergencyStep(
      title: 'Refugio',
      description: 'Preparea место para protegerse',
      icon: Icons.home,
    ),
  ];

  List<EmergencyStep> get steps => _steps;

  void activate() {
    _active = true;
    _step = 0;
    // Keep screen on
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top], // Hide system bars for max space
    );
    WakelockPlus.enable();
    notifyListeners();
  }

  void deactivate() {
    _active = false;
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);
    WakelockPlus.disable();
    notifyListeners();
  }

  void toggle() {
    if (_active) {
      deactivate();
    } else {
      activate();
    }
  }

  void nextStep() {
    if (_step < _steps.length - 1) {
      _step++;
      notifyListeners();
    }
  }

  void prevStep() {
    if (_step > 0) {
      _step--;
      notifyListeners();
    }
  }

  void goToStep(int index) {
    if (index >= 0 && index < _steps.length) {
      _step = index;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    deactivate();
    super.dispose();
  }
}

class EmergencyStep {
  final String title;
  final String description;
  final IconData icon;

  const EmergencyStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Full-screen emergency mode UI — designed for tablet
class EmergencyModePage extends StatelessWidget {
  final VoidCallback? onOpenTools;
  final VoidCallback? onOpenDirectory;
  final VoidCallback? onActivateSos;
  final VoidCallback? onOpenFlashlight;
  final VoidCallback? onOpenCompass;

  const EmergencyModePage({
    super.key,
    this.onOpenTools,
    this.onOpenDirectory,
    this.onActivateSos,
    this.onOpenFlashlight,
    this.onOpenCompass,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: EmergencyModeController.instance,
      builder: (context, _) {
        final ctrl = EmergencyModeController.instance;

        return Scaffold(
          backgroundColor: const Color(0xFF4A0000), // Dark red, fallback for shade950
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.red.shade900,
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'MODO EMERGENCIA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: ctrl.deactivate,
                        tooltip: 'Salir del modo emergencia',
                      ),
                    ],
                  ),
                ),

                // Quick actions bar
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.red.shade800,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _quickAction(
                        icon: Icons.phone,
                        label: 'Llamar',
                        onTap: onOpenDirectory,
                      ),
                      _quickAction(
                        icon: Icons.sos,
                        label: 'SOS',
                        onTap: onActivateSos,
                        color: Colors.orange,
                      ),
                      _quickAction(
                        icon: Icons.flashlight_on,
                        label: 'Linterna',
                        onTap: onOpenFlashlight,
                      ),
                      _quickAction(
                        icon: Icons.explore,
                        label: 'Brújula',
                        onTap: onOpenCompass,
                      ),
                      _quickAction(
                        icon: Icons.build,
                        label: 'Tools',
                        onTap: onOpenTools,
                      ),
                    ],
                  ),
                ),

                // Main content — step by step
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Progress indicator
                        Row(
                          children: List.generate(ctrl.steps.length, (i) {
                            final isActive = i == ctrl.step;
                            final isComplete = i < ctrl.step;
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isComplete 
                                    ? Colors.green 
                                    : (isActive ? Colors.white : Colors.red.shade700),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 32),

                        // Current step
                        Expanded(
                          child: GestureDetector(
                            onHorizontalDragEnd: (d) {
                              if (d.primaryVelocity! < 0) {
                                ctrl.nextStep();
                              } else if (d.primaryVelocity! > 0) {
                                ctrl.prevStep();
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    ctrl.steps[ctrl.step].icon,
                                    size: 80,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    ctrl.steps[ctrl.step].title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    ctrl.steps[ctrl.step].description,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: ctrl.step > 0 ? ctrl.prevStep : null,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Anterior'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              ),
                            ),
                            Text(
                              '${ctrl.step + 1} / ${ctrl.steps.length}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: ctrl.step < ctrl.steps.length - 1 
                                ? ctrl.nextStep 
                                : ctrl.deactivate,
                              icon: Icon(
                                ctrl.step < ctrl.steps.length - 1 
                                  ? Icons.arrow_forward 
                                  : Icons.check
                              ),
                              label: Text(
                                ctrl.step < ctrl.steps.length - 1 
                                  ? 'Siguiente' 
                                  : 'Listo'
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom tip
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black26,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swipe, color: Colors.white54, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Desliza ← → para navegar',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
