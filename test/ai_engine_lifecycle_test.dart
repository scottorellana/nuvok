import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/ai_engine.dart';
import 'package:nuvok/modules/ai/llama_server.dart' show LlamaStatus;

/// El modelo pesa 3,4 GB. Cargarlo y soltarlo no es gratis: es el mayor gasto
/// de batería y de RAM de toda la app, y en iOS un modelo residente es el
/// candidato número uno a que el sistema mate a Nuvok cuando el usuario abre
/// la linterna.
void main() {
  group('cuándo hay que recargar el modelo', () {
    const modelo = '/lib/models/gemma-4-E2B-it-Q4_K_M.gguf';
    const otro = '/lib/models/qwen2.5-1.5b-instruct-q4_k_m.gguf';

    test('el MISMO modelo ya cargado no se recarga', () {
      expect(
        needsReload(
            status: LlamaStatus.running, loadedPath: modelo, wantedPath: modelo),
        isFalse,
        reason: 'ir de un especialista a otro descargaba y volvía a cargar el '
            'mismo archivo de 3,4 GB, y todos comparten modelo',
      );
    });

    test('otro modelo sí se carga', () {
      expect(
        needsReload(
            status: LlamaStatus.running, loadedPath: modelo, wantedPath: otro),
        isTrue,
      );
    });

    test('si no hay nada cargado, se carga', () {
      expect(
        needsReload(
            status: LlamaStatus.stopped, loadedPath: null, wantedPath: modelo),
        isTrue,
      );
    });

    test('un motor en error se reintenta aunque la ruta coincida', () {
      expect(
        needsReload(
            status: LlamaStatus.error, loadedPath: modelo, wantedPath: modelo),
        isTrue,
        reason: 'quedarse en error para siempre deja al usuario sin IA',
      );
    });

    test('estado running con ruta perdida se recarga', () {
      // Incoherencia defensiva: si decimos "corriendo" sin saber qué, hay que
      // rehacerlo en vez de responder con un modelo desconocido.
      expect(
        needsReload(
            status: LlamaStatus.running, loadedPath: null, wantedPath: modelo),
        isTrue,
      );
    });
  });

  group('cuándo soltar el modelo al irse a segundo plano', () {
    test('una salida momentánea NO lo suelta', () {
      // Mirar una notificación y volver no puede costar recargar 3,4 GB.
      expect(
        shouldUnloadAfterBackground(const Duration(seconds: 5)),
        isFalse,
      );
    });

    test('irse de verdad lo suelta', () {
      expect(
        shouldUnloadAfterBackground(backgroundUnloadDelay),
        isTrue,
        reason: 'un modelo residente en segundo plano es el candidato ideal a '
            'que iOS mate la app cuando el usuario abre la linterna',
      );
      expect(
        shouldUnloadAfterBackground(const Duration(minutes: 5)),
        isTrue,
      );
    });

    test('el margen es corto pero no instantáneo', () {
      expect(backgroundUnloadDelay.inSeconds, greaterThanOrEqualTo(20));
      expect(backgroundUnloadDelay.inMinutes, lessThanOrEqualTo(2));
    });
  });
}
