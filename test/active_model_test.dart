import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/active_model.dart';

void main() {
  const gemma4 = 'gemma-4-E2B-it-Q4_K_M.gguf'; // sembrado, ~3.4GB
  const qwen05 = 'qwen2.5-0.5b-instruct-q4_k_m.gguf'; // fallback, ~490MB
  const llama1b = 'Llama-3.2-1B-Instruct-Q4_K_M.gguf'; // bajado de Depósito

  int gb(num n) => (n * 1024 * 1024 * 1024).round();

  group('resolveActiveModel', () {
    test('el elegido gana si está instalado y cabe en RAM', () {
      final r = resolveActiveModel(
        installed: const [gemma4, qwen05, llama1b],
        chosen: llama1b,
        freeRamBytes: gb(6),
      );
      expect(r, llama1b);
    });

    test('elegido que no cabe en RAM cae al mejor instalado que sí cabe', () {
      // Gemma 4 (~3.4GB) no cabe con poca RAM libre; cae al 0.5B.
      final r = resolveActiveModel(
        installed: const [gemma4, qwen05],
        chosen: gemma4,
        freeRamBytes: gb(2),
      );
      expect(r, qwen05);
    });

    test('sin elección previa usa el mejor instalado (Gemma 4 sembrado)', () {
      final r = resolveActiveModel(
        installed: const [qwen05, gemma4],
        chosen: null,
        freeRamBytes: gb(8),
      );
      expect(r, gemma4);
    });

    test('elegido borrado (ya no instalado) cae al mejor disponible', () {
      final r = resolveActiveModel(
        installed: const [qwen05],
        chosen: llama1b, // ya no está
        freeRamBytes: gb(8),
      );
      expect(r, qwen05);
    });

    test('nada instalado devuelve null', () {
      final r = resolveActiveModel(
        installed: const [],
        chosen: null,
        freeRamBytes: gb(8),
      );
      expect(r, isNull);
    });

    test('freeRam desconocida (null) no bloquea la elección', () {
      final r = resolveActiveModel(
        installed: const [gemma4, qwen05],
        chosen: gemma4,
        freeRamBytes: null,
      );
      expect(r, gemma4);
    });
  });

  group('modelDisplayName', () {
    test('un modelo del catálogo de Depósito muestra su nombre curado', () {
      expect(modelDisplayName('google_gemma-3-1b-it-Q4_0.gguf'),
          contains('Gemma 3 1B'));
    });

    test('un modelo de la cadena de especialistas muestra nombre legible', () {
      expect(modelDisplayName(qwen05).toLowerCase(), contains('qwen'));
      expect(modelDisplayName(gemma4).toLowerCase(), contains('gemma 4'));
    });

    test('un .gguf desconocido se embellece desde el nombre de archivo', () {
      final n = modelDisplayName('mistral-7b-instruct-v0.3.Q4_K_M.gguf');
      expect(n, isNot(contains('.gguf')));
      expect(n.toLowerCase(), contains('mistral'));
    });
  });
}
