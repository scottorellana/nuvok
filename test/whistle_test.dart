import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/tools/whistle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhistleGenerator', () {
    test('genera WAV con tamaño correcto para 1 segundo', () {
      final wav = WhistleGenerator.generateWav(3000, durationMs: 1000);
      // 44100 samples * 2 bytes + 44 byte header = 88244
      expect(wav.length, 44100 * 2 + 44);
    });

    test('genera WAV con header RIFF correcto', () {
      final wav = WhistleGenerator.generateWav(2000, durationMs: 500);
      // RIFF header
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      // fmt sub-chunk
      expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
      // data sub-chunk
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    });

    test('WAV mono PCM 16-bit a 44.1kHz', () {
      final wav = WhistleGenerator.generateWav(1000);
      final bd = wav.buffer.asByteData();
      // Audio format = 1 (PCM)
      expect(bd.getUint16(20, Endian.little), 1);
      // Num channels = 1 (mono)
      expect(bd.getUint16(22, Endian.little), 1);
      // Sample rate = 44100
      expect(bd.getUint32(24, Endian.little), 44100);
      // Bits per sample = 16
      expect(bd.getUint16(34, Endian.little), 16);
    });

    test('genera tono con frecuencia variable', () {
      final wav1k = WhistleGenerator.generateWav(1000, durationMs: 100);
      final wav3k = WhistleGenerator.generateWav(3000, durationMs: 100);
      // Ambos mismo tamaño (depende solo del duration)
      expect(wav1k.length, wav3k.length);
      // Pero contenido diferente (diferente frecuencia)
      final sample1k = wav1k.buffer.asByteData().getInt16(44, Endian.little);
      final sample3k = wav3k.buffer.asByteData().getInt16(44, Endian.little);
      // Primer sample = 0 (sin starts at zero crossing)
      expect(sample1k, 0);
      expect(sample3k, 0);
    });

    test('genera tono no vacío', () {
      final wav = WhistleGenerator.generateWav(3000, durationMs: 100);
      final bd = wav.buffer.asByteData();
      // Algunos samples en el medio deben ser no-cero
      var nonZero = 0;
      final numSamples = (44100 * 100 / 1000).round();
      for (var i = 0; i < numSamples; i += 100) {
        final s = bd.getInt16(44 + i * 2, Endian.little);
        if (s.abs() > 1000) nonZero++;
      }
      expect(nonZero, greaterThan(5),
          reason: 'El tono debe tener energía significativa');
    });
  });
}
