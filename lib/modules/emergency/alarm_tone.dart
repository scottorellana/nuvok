// El tono de la alarma SOS, generado en memoria.
//
// La alarma se documentaba como "fuerte y persistente" pero solo VIBRABA
// (HapticFeedback en bucle). Un teléfono boca abajo sobre una cama, en un
// bolsillo o en otra habitación no despierta a nadie con vibración: el SOS
// de un vecino se perdía en silencio.
//
// Se genera el WAV en memoria en vez de empaquetar un asset: la app ya lo
// hace así en el silbato (whistle.dart) con just_audio, no añade peso al
// instalador ligero, y un tono sintetizado no puede corromperse ni faltar.
import 'dart:math' as math;
import 'dart:typed_data';

const int _sampleRate = 44100;

/// Dos tonos que alternan: el oído humano reconoce el BARRIDO como
/// emergencia, mientras que un pitido plano se confunde con cualquier
/// notificación. Frecuencias altas porque atraviesan mejor el ruido y las
/// paredes de un edificio.
const double _lowHz = 740; // F#5
const double _highHz = 1174; // D6
const int _sweepMs = 350; // cada medio ciclo de la sirena

/// Alarma sintetizada lista para reproducir en bucle.
Uint8List buildAlarmWav({int durationMs = 1400}) {
  final numSamples = (_sampleRate * durationMs / 1000).round();
  final dataSize = numSamples * 2; // PCM 16-bit mono
  final bytes = ByteData(44 + dataSize);

  // Cabecera RIFF/WAVE.
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // tamaño del bloque fmt
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, _sampleRate, Endian.little);
  bytes.setUint32(28, _sampleRate * 2, Endian.little); // byte rate
  bytes.setUint16(32, 2, Endian.little); // block align
  bytes.setUint16(34, 16, Endian.little); // bits por muestra
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);

  // Fase continua: saltar de frecuencia sin recalcular la fase produce un
  // chasquido en cada cambio, que suena a fallo y no a alarma.
  var phase = 0.0;
  for (var i = 0; i < numSamples; i++) {
    final ms = i * 1000 / _sampleRate;
    final high = (ms ~/ _sweepMs) % 2 == 1;
    final freq = high ? _highHz : _lowHz;
    phase += 2 * math.pi * freq / _sampleRate;
    // 0.92 de fondo de escala: fuerte, sin recortar la onda (el clipping
    // distorsiona y hace que suene a ruido, no a sirena).
    final value = (math.sin(phase) * 32767 * 0.92).round();
    bytes.setInt16(44 + i * 2, value.clamp(-32768, 32767), Endian.little);
  }
  return bytes.buffer.asUint8List();
}
