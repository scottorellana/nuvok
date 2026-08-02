import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/alarm_tone.dart';

/// La alarma SOS se documenta como "alarma fuerte y persistente", pero solo
/// vibraba: HapticFeedback.heavyImpact en bucle. Un teléfono boca abajo sobre
/// una cama, en un bolsillo o en otra habitación no despierta a nadie con
/// vibración — y el SOS de un vecino se perdía.
///
/// Estas pruebas verifican el TONO que se genera, sin reproducir audio.
void main() {
  group('el tono de alarma es audible de verdad', () {
    test('genera un WAV válido', () {
      final wav = buildAlarmWav(durationMs: 1000);
      // Cabecera RIFF/WAVE — si esto falla, no suena nada en ningún lado.
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(wav.length, greaterThan(44), reason: 'cabecera + muestras');
    });

    test('dura lo pedido a 44.1 kHz, 16 bits mono', () {
      final wav = buildAlarmWav(durationMs: 1000);
      const expectedSamples = 44100;
      expect(wav.length, 44 + expectedSamples * 2);
    });

    test('barre entre dos tonos: una sirena, no un pitido plano', () {
      // Un tono fijo se confunde con una notificación cualquiera. El barrido
      // (dos tonos alternos) es lo que el oído reconoce como emergencia.
      final wav = buildAlarmWav(durationMs: 1000);
      // Comparar energía de dos ventanas separadas: deben diferir en forma.
      int zeroCross(List<int> b, int fromByte, int toByte) {
        var crossings = 0;
        int? prev;
        for (var i = fromByte; i + 1 < toByte; i += 2) {
          final s = (b[i + 1] << 8) | b[i]; // little-endian
          final signed = s > 32767 ? s - 65536 : s;
          if (prev != null && (prev < 0) != (signed < 0)) crossings++;
          prev = signed;
        }
        return crossings;
      }

      // Ventanas de 100 ms en los dos semiperiodos del barrido.
      const bytesPer100ms = 4410 * 2;
      final a = zeroCross(wav, 44, 44 + bytesPer100ms);
      final b = zeroCross(wav, 44 + bytesPer100ms * 4, 44 + bytesPer100ms * 5);
      expect(a, isNot(b),
          reason: 'ambas ventanas tienen la misma frecuencia: no hay barrido');
    });

    test('la amplitud es alta: una alarma no se pide con timidez', () {
      final wav = buildAlarmWav(durationMs: 200);
      var peak = 0;
      for (var i = 44; i + 1 < wav.length; i += 2) {
        final s = (wav[i + 1] << 8) | wav[i];
        final signed = s > 32767 ? s - 65536 : s;
        final abs = signed.abs();
        if (abs > peak) peak = abs;
      }
      expect(peak, greaterThan(20000),
          reason: 'pico bajo = alarma inaudible con ruido ambiente');
    });

    test('duración por defecto apta para repetir en bucle', () {
      final wav = buildAlarmWav();
      expect(wav.length, greaterThan(44 + 44100)); // ≥ 0.5 s de audio
    });
  });
}
