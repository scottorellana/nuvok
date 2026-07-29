import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/model_catalog.dart';
import 'package:nuvok/modules/ai/agents/agent_catalog.dart';

void main() {
  test('la clase de modelo de cada agente resuelve en ambas plataformas', () {
    for (final a in AgentCatalog.all) {
      for (final desktop in [true, false]) {
        final m = ModelCatalog.resolveClass(a.modelClass, isDesktop: desktop);
        expect(m.fileName.endsWith('.gguf'), isTrue,
            reason: '${a.id} desktop=$desktop no resolvió a un .gguf');
      }
    }
  });

  test('desktop resuelve a un modelo mayor que el de teléfono', () {
    final d = ModelCatalog.resolveClass(ModelClass.general, isDesktop: true);
    final p = ModelCatalog.resolveClass(ModelClass.general, isDesktop: false);
    expect(d.sizeBytes, greaterThan(p.sizeBytes));
  });

  test('la cadena de fallback termina en el modelo más chico', () {
    final chain = ModelCatalog.chainFrom(ModelCatalog.byId('general-e4b')!);
    expect(chain.map((m) => m.id).toList(), [
      'general-e4b',
      'general-e2b',
      'general-1.5b',
      'general-0.5b',
    ], reason: 'la cadena es 100% Apache 2.0: se retiraron Qwen 3B (licencia '
        'no comercial) y Gemma 1B (obliga a trasladar términos)');
    // Estrictamente decreciente en tamaño.
    for (var i = 1; i < chain.length; i++) {
      expect(chain[i].sizeBytes, lessThan(chain[i - 1].sizeBytes));
    }
  });

  test('byId devuelve null si no existe', () {
    expect(ModelCatalog.byId('nope'), isNull);
  });

  test('cada entrada tiene url, fileName y sha256 no vacíos', () {
    for (final m in ModelCatalog.all) {
      expect(m.fileName.endsWith('.gguf'), isTrue);
      expect(m.url, startsWith('https://'));
      expect(m.sha256, isNotEmpty);
      expect(m.sizeBytes, greaterThan(0));
    }
  });

  test('el fallback ligero, si existe, apunta a una entrada real', () {
    for (final m in ModelCatalog.all) {
      if (m.liteFallbackId != null) {
        expect(ModelCatalog.byId(m.liteFallbackId!), isNotNull);
      }
    }
  });
}
