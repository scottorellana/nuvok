// Digital Whistle — high-pitched emergency sound generator.
// Generates real WAV audio in memory and plays it with just_audio.
// Configurable frequency (800Hz – 4000Hz), continuous or pulsed mode.
//
// The whistle tone is a pure sine wave. For emergency whistle simulation,
// 3000Hz is optimal: audible at long distances, penetrates ambient noise.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/locale_service.dart';

/// Generates a WAV file in memory with a pure sine wave tone.
class WhistleGenerator {
  static const int sampleRate = 44100;

  /// Generate a WAV file (as Uint8List) for the given frequency and duration.
  /// Format: PCM 16-bit, mono, 44.1kHz.
  static Uint8List generateWav(double frequency, {int durationMs = 3000}) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * 2; // 2 bytes per 16-bit sample
    final fileSize = 44 + dataSize; // WAV header (44 bytes) + data

    final bytes = ByteData(fileSize);

    // RIFF header
    bytes.setUint8(0, 0x52); // 'R'
    bytes.setUint8(1, 0x49); // 'I'
    bytes.setUint8(2, 0x46); // 'F'
    bytes.setUint8(3, 0x46); // 'F'
    bytes.setUint32(4, fileSize - 8, Endian.little);
    bytes.setUint8(8, 0x57); // 'W'
    bytes.setUint8(9, 0x41); // 'A'
    bytes.setUint8(10, 0x56); // 'V'
    bytes.setUint8(11, 0x45); // 'E'

    // fmt sub-chunk
    bytes.setUint8(12, 0x66); // 'f'
    bytes.setUint8(13, 0x6D); // 'm'
    bytes.setUint8(14, 0x74); // 't'
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // sub-chunk size
    bytes.setUint16(20, 1, Endian.little); // audio format = PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little); // sample rate
    bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little); // block align
    bytes.setUint16(34, 16, Endian.little); // bits per sample

    // data sub-chunk
    bytes.setUint8(36, 0x64); // 'd'
    bytes.setUint8(37, 0x61); // 'a'
    bytes.setUint8(38, 0x74); // 't'
    bytes.setUint8(39, 0x61); // 'a'
    bytes.setUint32(40, dataSize, Endian.little);

    // Generate sine wave samples with fade-in/fade-out envelope
    const fadeMs = 20; // 20ms fade to avoid clicks
    final fadeSamples = (sampleRate * fadeMs / 1000).round();

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      var amplitude = sin(2 * pi * frequency * t);

      // Fade-in envelope
      if (i < fadeSamples) {
        amplitude *= i / fadeSamples;
      }
      // Fade-out envelope at the end
      if (i > numSamples - fadeSamples) {
        amplitude *= (numSamples - i) / fadeSamples;
      }

      // 0.85 volume to prevent clipping, 16-bit signed
      final sample = (amplitude * 32767 * 0.85).toInt().clamp(-32768, 32767);
      bytes.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }
}

/// Persists generated whistle tones as WAV files for native audio backends.
///
/// just_audio's in-memory StreamAudioSource can be fragile on desktop when the
/// native decoder probes byte ranges. A real WAV file exercises the same path
/// as macOS afplay/AVFoundation and is much more reliable for an emergency
/// tool.
class WhistleToneFile {
  static Future<File> write(double frequency, {int durationMs = 2000}) async {
    final dir = await Directory.systemTemp.createTemp('prepper_pad_whistle_');
    final path = '${dir.path}/whistle_${frequency.round()}hz.wav';
    final file = File(path);
    await file.writeAsBytes(
      WhistleGenerator.generateWav(frequency, durationMs: durationMs),
      flush: true,
    );
    return file;
  }

  static Future<void> delete(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
    try {
      final parent = file.parent;
      if (await parent.exists()) await parent.delete();
    } catch (_) {}
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
  String? _lastError;

  final AudioPlayer _audioPlayer = AudioPlayer();
  File? _toneFile;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _pulseTimer;

  // Preset frequencies — 3kHz is standard for emergency whistles
  static const Map<String, double> presets = {
    '1 kHz': 1000,
    '2 kHz': 2000,
    '3 kHz 🔊': 3000,
    '4 kHz': 4000,
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _audioPlayer.setLoopMode(LoopMode.one);
  }

  @override
  void dispose() {
    _stopWhistle();
    _audioPlayer.dispose();
    WhistleToneFile.delete(_toneFile);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadTone(double frequency) async {
    final nextFile = await WhistleToneFile.write(frequency);
    final previousFile = _toneFile;
    try {
      await _audioPlayer.setFilePath(
        nextFile.path,
        initialPosition: Duration.zero,
      );
      _toneFile = nextFile;
      await WhistleToneFile.delete(previousFile);
    } catch (_) {
      await WhistleToneFile.delete(nextFile);
      rethrow;
    }
  }

  Future<void> _startWhistle() async {
    setState(() {
      _isPlaying = true;
      _lastError = null;
    });

    try {
      HapticFeedback.heavyImpact();
      await WakelockPlus.enable();

      await _audioPlayer.setVolume(1.0);
      await _loadTone(_frequency);
      await _audioPlayer.play();

      if (_pulsedMode) {
        _pulseController.repeat(reverse: true);
        _pulseTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
          HapticFeedback.heavyImpact();
          if (_flashOnPulse) {
            _audioPlayer.setVolume(0);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_isPlaying) _audioPlayer.setVolume(1.0);
            });
          }
        });
      }
    } catch (e) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
      _pulseController.stop();
      await _audioPlayer.stop();
      await WhistleToneFile.delete(_toneFile);
      _toneFile = null;
      await WakelockPlus.disable();
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _lastError = 'No se pudo reproducir el silbato: $e';
      });
    }
  }

  void _stopWhistle() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
    _pulseController.stop();
    _audioPlayer.stop();
    WhistleToneFile.delete(_toneFile);
    _toneFile = null;
    WakelockPlus.disable();
    if (mounted) setState(() => _isPlaying = false);
  }

  void _toggleWhistle() {
    if (_isPlaying) {
      _stopWhistle();
    } else {
      _startWhistle();
    }
  }

  Future<void> _changeFrequency(double freq) async {
    setState(() => _frequency = freq);
    if (_isPlaying) {
      // Regenerate tone at new frequency and keep playing.
      await _loadTone(freq);
      await _audioPlayer.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Emergency palette — designed for dark theme with WCAG AA contrast.
    // The whistle is a safety tool: the UI must be instantly readable in
    // low-light panic situations (night, storm, power outage).
    const darkSurface = Color(0xFF1A1F12);
    const dimText = Color(0xFF8A9070);
    const brightText = Color(0xFFE8F0D8);
    final activeColor = _isPlaying
        ? const Color(0xFFEF5350) // red-400 — pops on dark
        : const Color(0xFF8C9E5E); // olive — app accent
    return Scaffold(
      backgroundColor:
          _isPlaying && _flashOnPulse ? const Color(0xFFB71C1C) : null,
      appBar: AppBar(
        title: Text(tr(context, 'emergencyWhistle')),
        backgroundColor: _isPlaying ? const Color(0xFFC62828) : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Big whistle button
            Expanded(
              child: Center(
                child: Semantics(
                  button: true,
                  enabled: true,
                  label: _isPlaying
                      ? 'Detener silbato de emergencia'
                      : 'Activar silbato de emergencia',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _toggleWhistle,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final scale = _pulsedMode && _isPlaying
                              ? _pulseAnimation.value
                              : (_isPlaying ? 1.05 : 1.0);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: _isPlaying
                                      ? [
                                          const Color(0xFFEF5350),
                                          const Color(0xFFB71C1C),
                                        ]
                                      : [
                                          const Color(0xFFE57373),
                                          const Color(0xFFC62828),
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.5),
                                    blurRadius: _isPlaying ? 50 : 24,
                                    spreadRadius: _isPlaying ? 12 : 6,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isPlaying ? Icons.stop : Icons.campaign,
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
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Frequency display
            Text(
              '${_frequency.round()} Hz',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: _isPlaying ? const Color(0xFFEF5350) : brightText,
              ),
            ),

            const SizedBox(height: 16),

            // Frequency selector
            Card(
              color: darkSurface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frecuencia',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: dimText,
                      ),
                    ),
                    Slider(
                      value: _frequency,
                      min: 800,
                      max: 4000,
                      divisions: 32,
                      label: '${_frequency.round()} Hz',
                      activeColor: activeColor,
                      onChanged: _changeFrequency,
                    ),
                    Wrap(
                      spacing: 8,
                      children: presets.entries.map((e) {
                        return ActionChip(
                          label: Text(e.key),
                          onPressed: () => _changeFrequency(e.value),
                          backgroundColor: _frequency == e.value
                              ? const Color(0xFF3D2A1F)
                              : darkSurface,
                          labelStyle: TextStyle(
                            color: _frequency == e.value
                                ? const Color(0xFFFFAB40)
                                : dimText,
                            fontWeight: _frequency == e.value
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Options
            Card(
              color: darkSurface,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Modo pulsado',
                        style: TextStyle(color: brightText)),
                    subtitle: const Text('Sonido intermitente — más detectable',
                        style: TextStyle(color: dimText)),
                    value: _pulsedMode,
                    onChanged: (v) => setState(() => _pulsedMode = v),
                  ),
                  SwitchListTile(
                    title: const Text('Flash de pantalla',
                        style: TextStyle(color: brightText)),
                    subtitle: const Text('Pantalla parpadea con el sonido',
                        style: TextStyle(color: dimText)),
                    value: _flashOnPulse,
                    onChanged: _pulsedMode
                        ? (v) => setState(() => _flashOnPulse = v)
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (_lastError != null) ...[
              Card(
                color: const Color(0xFF3A1F1F),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFFF8A80)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _lastError!,
                          style: const TextStyle(color: Color(0xFFFFCDD2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Info — dark amber card (was bright cream/white, unreadable on dark theme)
            Card(
              color: const Color(0xFF2A2018),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFFFAB40)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El silbato de 3 kHz es audible a mayor distancia. '
                        'Úsalo para atraer atención de rescatistas.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade200,
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

/// Custom AudioSource that wraps raw WAV bytes in memory.
class CustomAudioSource extends StreamAudioSource {
  final Uint8List _buffer;

  CustomAudioSource(this._buffer);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final safeStart = (start ?? 0).clamp(0, _buffer.length).toInt();
    final safeEnd = (end ?? _buffer.length).clamp(safeStart, _buffer.length).toInt();
    final length = safeEnd - safeStart;
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: length,
      offset: safeStart,
      stream: Stream.value(_buffer.sublist(safeStart, safeEnd)),
      contentType: 'audio/wav',
    );
  }
}
