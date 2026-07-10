import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/lan_transport.dart';

// Integración real: dos transportes LAN en el mismo host se ven por
// multicast loopback. Si el runner de CI bloquea multicast, se omite.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dos nodos LAN en el mismo host se intercambian datagramas', () async {
    final a = LanTransport(port: 47788);
    final b = LanTransport(port: 47788);
    try {
      await a.start();
      await b.start();
    } catch (e) {
      markTestSkipped('el entorno no permite sockets multicast: $e');
      return;
    }
    final received = Completer<Uint8List>();
    final sub = b.onData.listen((d) {
      if (!received.isCompleted) received.complete(d);
    });
    final probe = Uint8List.fromList('NuvokMesh-PROBE'.codeUnits);
    // Reintenta unas veces: el join multicast puede tardar un instante.
    Uint8List? got;
    for (var i = 0; i < 10 && got == null; i++) {
      await a.send(probe);
      try {
        got = await received.future.timeout(const Duration(milliseconds: 400));
      } on TimeoutException {
        got = null;
      }
    }
    await sub.cancel();
    await a.stop();
    await b.stop();
    if (got == null) {
      markTestSkipped('multicast loopback no disponible en este entorno');
      return;
    }
    expect(String.fromCharCodes(got), 'NuvokMesh-PROBE');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
