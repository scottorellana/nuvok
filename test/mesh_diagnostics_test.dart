import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_diagnostics.dart';

void main() {
  setUp(MeshDiagnostics.instance.reset);

  group('contadores por transporte', () {
    test('cuenta enviados y recibidos por separado', () {
      final d = MeshDiagnostics.instance;
      d.recordSent('ble', 120);
      d.recordSent('ble', 80);
      d.recordReceived('ble', 200);
      d.recordSent('lan', 50);

      expect(d.counters['ble']!.sent, 2);
      expect(d.counters['ble']!.sentBytes, 200);
      expect(d.counters['ble']!.received, 1);
      expect(d.counters['ble']!.receivedBytes, 200);
      expect(d.counters['lan']!.sent, 1);
      expect(d.counters['lan']!.received, 0);
    });

    test('un transporte sin tráfico no aparece inventado', () {
      expect(MeshDiagnostics.instance.counters['lora'], isNull);
    });
  });

  group('bitácora acotada', () {
    test('guarda los eventos más recientes', () {
      final d = MeshDiagnostics.instance;
      d.log('arranque');
      d.log('bluetooth encendido');
      expect(d.events.length, 2);
      expect(d.events.last.message, 'bluetooth encendido');
    });

    test('nunca crece sin límite: descarta lo más viejo', () {
      final d = MeshDiagnostics.instance;
      for (var i = 0; i < MeshDiagnostics.maxEvents + 40; i++) {
        d.log('evento $i');
      }
      expect(d.events.length, MeshDiagnostics.maxEvents,
          reason: 'en un teléfono con poca RAM la bitácora debe estar acotada');
      // Se conserva lo RECIENTE, que es lo que sirve para diagnosticar.
      expect(d.events.last.message,
          'evento ${MeshDiagnostics.maxEvents + 39}');
    });
  });

  group('reporte copiable', () {
    test('incluye contadores y eventos para pegarlos en un mensaje', () {
      final d = MeshDiagnostics.instance;
      d.recordSent('ble', 100);
      d.recordReceived('lan', 30);
      d.log('vecino encontrado');

      final text = d.snapshotText(
        peers: 2,
        queued: 1,
        transports: const ['ble: conectado (1 vecino)', 'lan: buscando'],
      );

      expect(text, contains('ble'));
      expect(text, contains('lan'));
      expect(text, contains('vecino encontrado'));
      expect(text, contains('2')); // pares
      expect(text.split('\n').length, greaterThan(4));
    });

    test('funciona sin tráfico ni eventos (recién instalado)', () {
      final text = MeshDiagnostics.instance
          .snapshotText(peers: 0, queued: 0, transports: const []);
      expect(text, isNotEmpty);
    });
  });
}
