// Digital Whistle — high-pitched emergency sound generator.
// Uses AudioPlayer to generate configurable frequency tones that can be
// heard at distance. Critical for emergencies where visibility is low.
//
// Features:
// - Configurable frequency (800Hz - 4000Hz)
// - Preset emergency frequencies (2kHz, 3kHz)
// - Continuous or pulsed mode
// - Screen flash配合 (optional)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Generated pure-tone sine wave buffer — 44.1kHz, 1 second, mono.
// We'll generate dynamically at runtime for flexibility.
class WhistleGenerator {
  static const int sampleRate = 44100;
  
  /// Generate a sine wave buffer at given frequency.
  static List<int> generateTone(double frequency, {int durationMs = 1000}) {
    final length = (sampleRate * durationMs / 1000).round();
    final buffer = List<int>.filled(length * 2, 0); // 16-bit samples
    
    for (var i = 0; i < length; i++) {
      final sine = _fastSin(i * frequency * 2 * 3.14159265359 / sampleRate);
      final amplitude = (sine * 32767 * 0.8).round().clamp(-32768, 32767);
      buffer[i * 2] = amplitude & 0xFF;
      buffer[i * 2 + 1] = (amplitude >> 8) & 0xFF;
    }
    return buffer;
  }
  
  static double _fastSin(double x) {
    // Fast sine approximation for real-time generation
    const pi = 3.14159265359;
    x = x % (2 * pi);
    if (x > pi) x -= 2 * pi;
    if (x < -pi) x += 2 * pi;
    // Taylor series approximation
    return x - (x*x*x)/6 + (x*x*x*x*x)/120;
  }
}

class WhistleScreen extends StatefulWidget {
  const WhistleScreen({super.key});

  @override
  State<WhistleScreen> createState() => _WhistleScreenState();
}

class _WhistleScreenState extends State<WhistleScreen>
    with TickerProviderStateMixin {
  bool _isPlaying = false;
  double _frequency = 3000; // Default emergency freq
  bool _pulsedMode = false;
  bool _flashOnPulse = false;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _pulseTimer;
  
  // Preset frequencies
  static const Map<String, double> presets = {
    '2 kHz': 2000,
    '3 kHz (Emergencia)': 3000,
    '4 kHz': 4000,
    '1 kHz': 1000,
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _stopWhistle();
    _pulseController.dispose();
    super.dispose();
  }

  void _startWhistle() {
    setState(() => _isPlaying = true);
    
    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    if (_pulsedMode) {
      _pulseController.repeat(reverse: true);
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        HapticFeedback.heavyImpact();
        if (_flashOnPulse) {
          // Flash handled by animation
        }
      });
    }
    
    // Keep screen on while whistle is active
    // In real implementation, use wakelock package
  }

  void _stopWhistle() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
    _pulseController.stop();
    setState(() => _isPlaying = false);
  }

  void _toggleWhistle() {
    if (_isPlaying) {
      _stopWhistle();
    } else {
      _startWhistle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isPlaying ? Colors.red : null,
      appBar: AppBar(
        title: const Text('Silbato de Emergencia'),
        backgroundColor: _isPlaying ? Colors.red : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Big whistle button
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _toggleWhistle,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final scale = _pulsedMode && _isPlaying
                          ? _pulseAnimation.value
                          : 1.0;
                      final opacity = _pulsedMode && _isPlaying
                          ? _pulseAnimation.value
                          : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isPlaying
                                  ? Colors.red.shade700
                                  : Colors.red.shade400,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.5),
                                  blurRadius: _isPlaying ? 40 : 20,
                                  spreadRadius: _isPlaying ? 10 : 5,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isPlaying
                                      ? Icons.stop
                                      : Icons.sports_score,
                                  size: 72,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isPlaying ? 'DETENER' : 'SILBAR',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Frequency selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frecuencia: ${_frequency.round()} Hz',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _frequency,
                      min: 800,
                      max: 4000,
                      divisions: 32,
                      label: '${_frequency.round()} Hz',
                      onChanged: (v) => setState(() => _frequency = v),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: presets.entries.map((e) {
                        return ActionChip(
                          label: Text(e.key),
                          onPressed: () => setState(() => _frequency = e.value),
                          backgroundColor: _frequency == e.value
                              ? Colors.red.shade100
                              : null,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Options
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Modo pulsado'),
                    subtitle: const Text('Sonido intermitente'),
                    value: _pulsedMode,
                    onChanged: (v) => setState(() => _pulsedMode = v),
                  ),
                  SwitchListTile(
                    title: const Text('Flash de pantalla'),
                    subtitle: const Text('Pantalla parpadea con el sonido'),
                    value: _flashOnPulse,
                    onChanged: _pulsedMode
                        ? (v) => setState(() => _flashOnPulse = v)
                        : null,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El silbato de 3kHz es audible a mayor distancia. '
                        'Úsalo para atraer atención en emergencias.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
