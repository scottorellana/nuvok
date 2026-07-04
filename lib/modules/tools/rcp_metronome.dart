// RCP Metronome — maintains steady 100-120 compressions per minute
// for cardiopulmonary resuscitation. Works offline, loud enough
// for noisy environments.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RcpMetronomeController extends ChangeNotifier {
  RcpMetronomeController._();
  static final RcpMetronomeController instance = RcpMetronomeController._();

  bool _playing = false;
  bool get playing => _playing;

  int _bpm = 110;
  int get bpm => _bpm;

  int _compressionCount = 0;
  int get compressionCount => _compressionCount;

  int _cycleCount = 0;
  int get cycleCount => _cycleCount;

  Timer? _timer;
  int _sinceLastBreath = 0;

  void setBpm(int bpm) {
    _bpm = bpm.clamp(100, 120);
    notifyListeners();
    if (_playing) {
      stop();
      play();
    }
  }

  void play() {
    if (_playing) return;
    _playing = true;
    _compressionCount = 0;
    _cycleCount = 0;
    _sinceLastBreath = 0;
    notifyListeners();

    final interval = Duration(milliseconds: (60000 / _bpm).round());
    _timer = Timer.periodic(interval, (_) {
      _compressionCount++;
      _sinceLastBreath++;

      // Give 2 breaths every 30 compressions
      if (_sinceLastBreath >= 30) {
        _cycleCount++;
        _sinceLastBreath = 0;
      }

      // Haptic + visual feedback for each compression
      HapticFeedback.mediumImpact();
      notifyListeners();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _playing = false;
    notifyListeners();
  }

  void reset() {
    stop();
    _compressionCount = 0;
    _cycleCount = 0;
    _sinceLastBreath = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Full-screen RCP metronome UI
class RcpMetronomePage extends StatelessWidget {
  const RcpMetronomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RcpMetronomeController.instance,
      builder: (context, _) {
        final ctrl = RcpMetronomeController.instance;
        final isPlaying = ctrl.playing;

        return Scaffold(
          backgroundColor:
              isPlaying ? Colors.red.shade900 : Colors.grey.shade900,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('RCP Metrónomo'),
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: Column(
              children: [
                // BPM selector
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('BPM: ',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 18)),
                      Text('${ctrl.bpm}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      const Text(' (100-120)',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
                if (!isPlaying)
                  Slider(
                    value: ctrl.bpm.toDouble(),
                    min: 100,
                    max: 120,
                    divisions: 20,
                    activeColor: Colors.red,
                    onChanged: (v) => ctrl.setBpm(v.round()),
                  ),

                const Spacer(),

                // Compression counter
                Text(
                  '${ctrl.compressionCount}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 120,
                      fontWeight: FontWeight.bold),
                ),
                const Text('COMPRESIONES',
                    style: TextStyle(color: Colors.white70, fontSize: 20)),

                const SizedBox(height: 20),

                // Cycle indicator (30:2)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Ciclo ${ctrl.cycleCount + 1} • ${ctrl._sinceLastBreath}/30',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),

                // Breath indicator
                if (ctrl._sinceLastBreath >= 25)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.air, color: Colors.white),
                        SizedBox(width: 8),
                        Text('2 RESPIRACIONES',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ],
                    ),
                  ),

                const Spacer(),

                // Controls
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reset
                      FloatingActionButton(
                        heroTag: 'reset',
                        backgroundColor: Colors.grey.shade700,
                        onPressed: ctrl.reset,
                        child: const Icon(Icons.refresh, color: Colors.white),
                      ),
                      // Play/Stop
                      FloatingActionButton.large(
                        heroTag: 'play',
                        backgroundColor:
                            isPlaying ? Colors.red.shade600 : Colors.green,
                        onPressed: isPlaying ? ctrl.stop : ctrl.play,
                        child: Icon(isPlaying ? Icons.stop : Icons.play_arrow,
                            color: Colors.white, size: 48),
                      ),
                    ],
                  ),
                ),

                // Instructions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    isPlaying
                        ? 'Presiona firmemente 5-6cm en el centro del pecho'
                        : 'Toca PLAY para iniciar el ritmo de compresiones',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
