// RCP Metronome — maintains steady 100-120 compressions per minute
// for cardiopulmonary resuscitation. Works offline, loud enough
// for noisy environments.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import '../../core/screen_awake.dart';
import 'package:flutter/services.dart';

import '../../core/nuvok_colors.dart';

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
  int _breathCueTicks = 0;
  bool get showBreathCue => _breathCueTicks > 0;

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
    _breathCueTicks = 0;
    notifyListeners();

    final interval = Duration(milliseconds: (60000 / _bpm).round());
    _timer = Timer.periodic(interval, (_) {
      _compressionCount++;
      _sinceLastBreath++;

      // Give 2 breaths every 30 compressions
      if (_sinceLastBreath >= 30) {
        _cycleCount++;
        _sinceLastBreath = 0;
        _breathCueTicks = 5;
      } else if (_breathCueTicks > 0) {
        _breathCueTicks--;
      }

      // Sonido + vibración + visual. Antes SOLO vibraba: con las manos
      // comprimiendo un pecho no se mira la pantalla, y la vibración se
      // pierde entre el propio movimiento — el ritmo hay que OÍRLO.
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
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
    _breathCueTicks = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Full-screen RCP metronome UI
class RcpMetronomePage extends StatefulWidget {
  const RcpMetronomePage({super.key});

  @override
  State<RcpMetronomePage> createState() => _RcpMetronomePageState();
}

class _RcpMetronomePageState extends State<RcpMetronomePage> {
  @override
  void initState() {
    super.initState();
    // Arranca SOLO: quien abre esta pantalla ya tiene las manos sobre un
    // pecho. Obligarle a buscar y tocar PLAY cuesta segundos que importan.
    RcpMetronomeController.instance.play();
    // Y la pantalla no puede dormirse a mitad de una reanimación.
    unawaited(ScreenAwake.acquire('rcp-metronome'));
  }

  @override
  void dispose() {
    RcpMetronomeController.instance.stop();
    unawaited(ScreenAwake.release('rcp-metronome'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RcpMetronomeController.instance,
      builder: (context, _) {
        final ctrl = RcpMetronomeController.instance;
        final isPlaying = ctrl.playing;

        return Scaffold(
          backgroundColor: ctrl.showBreathCue
              ? const Color(0xFF0D47A1)
              : isPlaying
                  ? NuvokColors.emergencyDeep
                  : NuvokColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(tr(context, 'rcpMetroTitle')),
            foregroundColor: Colors.white,
          ),
          // Scrollable: con el texto del sistema en grande esta pantalla
          // desbordaba y los botones PLAY/parar quedaban fuera — durante una
          // reanimación, sin poder detener ni reiniciar el conteo.
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
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
                    activeColor: const Color(0xFF8C9E5E),
                    onChanged: (v) => ctrl.setBpm(v.round()),
                  ),

                const Spacer(),

                // Compression counter / breathing cue
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: ctrl.showBreathCue
                      ? const Column(
                          key: ValueKey('breath-cue'),
                          children: [
                            Icon(Icons.air,
                                color: NuvokColors.white, size: 88),
                            SizedBox(height: 8),
                            Text(
                              '2 RESPIRACIONES',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: NuvokColors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '${ctrl.compressionCount}',
                          key: const ValueKey('compression-count'),
                          style: const TextStyle(
                              color: NuvokColors.white,
                              fontSize: 120,
                              fontWeight: FontWeight.bold),
                        ),
                ),
                Text(
                    ctrl.showBreathCue
                        ? tr(context, 'rcpMetroBreathe')
                        : tr(context, 'rcpMetroCompressions'),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 20)),

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
                    '${tr(context, 'rcpMetroCycle')} ${ctrl.cycleCount + 1} • ${ctrl._sinceLastBreath}/30',
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
                      color: NuvokColors.info,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.air, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(tr(context, 'rcpMetroTwoBreaths'),
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
                      Semantics(
                        button: true,
                        enabled: true,
                        label: tr(context, 'rcpMetroReset'),
                        child: FloatingActionButton(
                          heroTag: 'reset',
                          backgroundColor: NuvokColors.cardElevated,
                          onPressed: ctrl.reset,
                          child: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      ),
                      // Play/Stop
                      Semantics(
                        button: true,
                        enabled: true,
                        label: isPlaying
                            ? tr(context, 'rcpMetroStop')
                            : tr(context, 'rcpMetroStart'),
                        child: FloatingActionButton.large(
                          heroTag: 'play',
                          backgroundColor: isPlaying
                              ? NuvokColors.emergency
                              : NuvokColors.safe,
                          onPressed: isPlaying ? ctrl.stop : ctrl.play,
                          child: Icon(isPlaying ? Icons.stop : Icons.play_arrow,
                              color: Colors.white, size: 48),
                        ),
                      ),
                    ],
                  ),
                ),

                // Instructions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    ctrl.showBreathCue
                        ? tr(context, 'rcpMetroBreathHint')
                        : isPlaying
                            ? tr(context, 'rcpMetroPressHint')
                            : tr(context, 'rcpMetroPressHint'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14),
                  ),
                ),
              ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
