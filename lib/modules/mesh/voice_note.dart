// Clips de voz sobre el mesh — el "walkie-talkie" sin internet.
//
// El audio (AAC .m4a, mono, bitrate bajo) viaja en el payload JSON del
// MeshEnvelope como base64: reutiliza el cifrado por canal, el relay, el
// store-and-forward y la fragmentación BLE existentes sin tocar el protocolo.
// Este archivo es puro (sin plugins) y unit-testeable.
import 'dart:convert';
import 'dart:typed_data';

/// Máximo de bytes de audio por clip. 10 s de AAC mono a ~24 kbps ≈ 30 KB.
/// 40 KB deja margen y mantiene el datagrama final (base64 +33%, JSON,
/// cifrado y sobre) bajo el límite de fragmentación BLE (~64 KB) y del
/// datagrama UDP (65 507 B).
const int maxVoiceBytes = 40 * 1024;

/// Duración máxima de grabación. La UI corta sola al llegar aquí.
const Duration maxVoiceDuration = Duration(seconds: 10);

class VoiceNote {
  const VoiceNote({required this.audio, required this.durationMs});
  final Uint8List audio;
  final int durationMs;
}

/// Construye el payload mesh de un clip. Null si el audio está vacío o
/// excede [maxVoiceBytes] — el llamador debe grabar más corto, no trocear.
Map<String, dynamic>? encodeVoicePayload(Uint8List audio, int durationMs) {
  if (audio.isEmpty || audio.length > maxVoiceBytes) return null;
  return {'a': base64Encode(audio), 'd': durationMs, 'c': 'm4a'};
}

/// Extrae el clip de un payload recibido. Null ante cualquier corrupción —
/// un datagrama malformado jamás debe tirar el mesh.
VoiceNote? decodeVoicePayload(Map<String, dynamic> payload) {
  final a = payload['a'];
  final d = payload['d'];
  if (a is! String || d is! int) return null;
  try {
    final audio = base64Decode(a);
    if (audio.isEmpty || audio.length > maxVoiceBytes) return null;
    return VoiceNote(audio: audio, durationMs: d);
  } catch (_) {
    return null;
  }
}
