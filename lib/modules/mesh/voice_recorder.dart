// Grabación de clips de voz para el walkie-talkie mesh.
//
// Envoltorio fino sobre el paquete `record`: graba AAC (.m4a) mono a bitrate
// bajo para que 10 s quepan en un datagrama mesh (ver voice_note.dart). La
// UI mantiene presionado el micrófono; al soltar, [stop] devuelve los bytes.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

class VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();
  String? _path;
  DateTime? _startedAt;

  /// True mientras hay una grabación en curso.
  bool get recording => _startedAt != null;

  /// Pide permiso de micrófono si hace falta. False = denegado.
  Future<bool> hasPermission() async {
    try {
      return await _rec.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Empieza a grabar a un archivo temporal. False si no hay permiso o el
  /// dispositivo no puede grabar.
  Future<bool> start() async {
    if (recording) return true;
    try {
      if (!await _rec.hasPermission()) return false;
      final dir = Directory.systemTemp.createTempSync('ppvoice');
      _path = '${dir.path}/clip.m4a';
      await _rec.start(
        // AAC-LC mono a 24 kbps / 16 kHz: voz clara y ~3 KB/s — 10 s ≈ 30 KB,
        // bajo el límite de voice_note.maxVoiceBytes.
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 24000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _path!,
      );
      _startedAt = DateTime.now();
      return true;
    } catch (_) {
      _path = null;
      _startedAt = null;
      return false;
    }
  }

  /// Duración transcurrida de la grabación en curso.
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Detiene y devuelve (bytes, duraciónMs), o null si algo falló o el clip
  /// quedó vacío. El archivo temporal se borra siempre.
  Future<(Uint8List, int)?> stop() async {
    final startedAt = _startedAt;
    _startedAt = null;
    if (startedAt == null) return null;
    final durMs = DateTime.now().difference(startedAt).inMilliseconds;
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {
      path = null;
    }
    path ??= _path;
    _path = null;
    if (path == null) return null;
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      final bytes = await f.readAsBytes();
      unawaited(f.parent.delete(recursive: true).catchError((_) => f.parent));
      if (bytes.isEmpty || durMs < 300) return null; // toque accidental
      return (bytes, durMs);
    } catch (_) {
      return null;
    }
  }

  /// Cancela la grabación en curso descartando el audio.
  Future<void> cancel() async {
    _startedAt = null;
    try {
      await _rec.stop();
    } catch (_) {}
    final p = _path;
    _path = null;
    if (p != null) {
      try {
        File(p).parent.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _rec.dispose();
  }
}
