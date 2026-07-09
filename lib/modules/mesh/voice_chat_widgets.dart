// UI del walkie-talkie mesh: botón "mantén presionado para hablar" y la
// burbuja de nota de voz reproducible. Separado de mesh_page para mantener
// cada archivo enfocado.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/locale_service.dart';
import 'mesh_service.dart';
import 'voice_note.dart';
import 'voice_recorder.dart';

/// Botón de micrófono: mantener presionado graba (indicador rojo + contador),
/// soltar envía por el mesh, deslizar/cancelar descarta. Corta solo al llegar
/// a [maxVoiceDuration].
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({super.key, required this.onClip});

  /// Recibe (bytes, duraciónMs) del clip listo para enviar.
  final Future<void> Function(dynamic bytes, int durationMs) onClip;

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> {
  final _recorder = VoiceRecorder();
  Timer? _ticker;
  bool _recording = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    final ok = await _recorder.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'voiceMicPermission'))),
        );
      }
      return;
    }
    setState(() => _recording = true);
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      // Corte automático al máximo: lo grabado se envía igual.
      if (_recorder.elapsed >= maxVoiceDuration) {
        _finish();
      } else {
        setState(() {}); // refresca el contador
      }
    });
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    _ticker = null;
    if (!_recording) return;
    setState(() => _recording = false);
    final clip = await _recorder.stop();
    if (clip == null) return;
    final (bytes, durMs) = clip;
    await widget.onClip(bytes, durMs);
  }

  Future<void> _abort() async {
    _ticker?.cancel();
    _ticker = null;
    if (!_recording) return;
    setState(() => _recording = false);
    await _recorder.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final secs = _recorder.elapsed.inSeconds;
    return GestureDetector(
      onLongPressStart: (_) => _begin(),
      onLongPressEnd: (_) => _finish(),
      onLongPressCancel: _abort,
      child: Tooltip(
        message: tr(context, 'voiceHold'),
        child: _recording
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '0:${secs.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : IconButton.filledTonal(
                // Un toque corto solo enseña el gesto; grabar es mantener
                // presionado (lo captura el GestureDetector de arriba).
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(tr(context, 'voiceHold')),
                      duration: const Duration(seconds: 2)),
                ),
                icon: const Icon(Icons.mic),
              ),
      ),
    );
  }
}

/// Contenido de una burbuja de nota de voz: ▶️/⏸ + duración.
class VoiceBubbleContent extends StatefulWidget {
  const VoiceBubbleContent({
    super.key,
    required this.msgId,
    required this.payload,
  });

  final int msgId;
  final Map<String, dynamic> payload;

  @override
  State<VoiceBubbleContent> createState() => _VoiceBubbleContentState();
}

class _VoiceBubbleContentState extends State<VoiceBubbleContent> {
  AudioPlayer? _player;
  bool _playing = false;
  bool _broken = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player?.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final note = decodeVoicePayload(widget.payload);
    if (note == null) {
      setState(() => _broken = true);
      return;
    }
    try {
      final file = await MeshService.instance.voiceFile(widget.msgId, note);
      final p = _player ??= AudioPlayer();
      await p.setFilePath(file.path);
      setState(() => _playing = true);
      await p.play();
      await p.stop();
      await p.seek(Duration.zero);
    } catch (_) {
      _broken = true;
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final durMs = (widget.payload['d'] as num?)?.toInt() ?? 0;
    final secs = (durMs / 1000).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _broken ? null : _toggle,
          icon: Icon(_broken
              ? Icons.error_outline
              : _playing
                  ? Icons.stop_circle
                  : Icons.play_circle_fill),
          iconSize: 34,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Icon(Icons.graphic_eq,
            size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text('0:${secs.toString().padLeft(2, '0')}'),
      ],
    );
  }
}
