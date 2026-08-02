import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/agent_runtime.dart';
import 'package:nuvok/modules/ai/agents/model_catalog.dart';
import 'package:nuvok/modules/ai/llama_server.dart';

/// El guardián de RAM decide si un modelo cabe. Cuando no sabe medir, dice
/// que sí a todo: la tarjeta pone "Listo", el usuario toca, y la app muere
/// sin decir por qué. En Android eso pasaba SIEMPRE, porque Platform.isLinux
/// es false ahí aunque /proc/meminfo exista.
void main() {
  group('parseMemAvailable', () {
    test('lee MemAvailable, que es la cifra que importa', () {
      const meminfo = '''
MemTotal:        3900000 kB
MemFree:          210000 kB
MemAvailable:    1850000 kB
Cached:          1200000 kB
''';
      expect(parseMemAvailable(meminfo), 1850000 * 1024,
          reason: 'MemFree en un teléfono en uso es casi siempre pequeña y '
              'haría rechazar modelos que sí caben');
    });

    test('kernel viejo sin MemAvailable: aproxima en vez de rendirse', () {
      const meminfo = '''
MemTotal:        2000000 kB
MemFree:          150000 kB
Cached:           600000 kB
''';
      expect(parseMemAvailable(meminfo), (150000 + 600000) * 1024,
          reason: 'rendirse aquí devuelve null, y null significa "cabe todo"');
    });

    test('basura ilegible devuelve null, no un número inventado', () {
      expect(parseMemAvailable('no soy meminfo'), isNull);
      expect(parseMemAvailable(''), isNull);
    });

    test('tolera espaciado y tabuladores del formato real', () {
      expect(parseMemAvailable('MemAvailable:\t 1024 kB'), 1024 * 1024);
    });
  });

  group('el guardián usa la medida para decidir', () {
    test('un modelo que no cabe en la RAM libre no queda listo', () {
      final grande = ModelCatalog.all.reduce(
          (a, b) => a.sizeBytes > b.sizeBytes ? a : b);
      final status = AgentRuntime.resolve(
        model: grande,
        installedFileNames: {grande.fileName},
        // Justo por debajo de lo que el modelo necesita con el margen de
        // seguridad: un teléfono modesto con la memoria ya ocupada.
        freeRamBytes: (grande.sizeBytes / AgentRuntime.ramSafety).round() - 1,
      );
      expect(status.state, isNot(AgentInstallState.ready),
          reason: 'decir "Listo" aquí mata la app al tocar el especialista');
    });

    test('con RAM de sobra sí queda listo', () {
      final m = ModelCatalog.all.first;
      final status = AgentRuntime.resolve(
        model: m,
        installedFileNames: {m.fileName},
        freeRamBytes: m.sizeBytes * 10,
      );
      expect(status.state, AgentInstallState.ready);
    });
  });
}
