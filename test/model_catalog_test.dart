import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/model_catalog.dart';
import 'package:nuvok/modules/ai/agents/agent_catalog.dart';

void main() {
  test('cada modelId de agente existe en el catálogo de modelos', () {
    for (final a in AgentCatalog.all) {
      expect(ModelCatalog.byId(a.modelId), isNotNull,
          reason: '${a.id} apunta a modelId inexistente ${a.modelId}');
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
