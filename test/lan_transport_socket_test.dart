import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/lan_transport.dart';

// Real-socket integration test for the LAN transport: two transports on the
// same host over loopback UDP. This is what actually proves "a datagram sent
// by one device is received by another" — the exact thing that was failing in
// the field — rather than only testing the router with a fake transport.
//
// Uses a non-default port so it can't collide with a running app instance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un datagrama enviado por A llega a B por la LAN real', () async {
    final a = LanTransport(port: 47921);
    final b = LanTransport(port: 47921);
    await a.start();
    await b.start();

    final received = <Uint8List>[];
    final sub = b.onData.listen(received.add);

    // Give the sockets a moment to finish joining the multicast group.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final payload = Uint8List.fromList([1, 2, 3, 4, 5, 42, 99]);
    await a.send(payload);

    // Poll for delivery instead of a fixed sleep.
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (received.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    await sub.cancel();
    await a.stop();
    await b.stop();

    expect(received, isNotEmpty,
        reason: 'B debe recibir el datagrama que A envió por la LAN local');
    expect(received.first, equals(payload));
  });

  test('stop y start de nuevo no deja la recepción muerta', () async {
    final t = LanTransport(port: 47922);
    await t.start();
    await t.stop();
    // Antes: stop() cerraba el StreamController y start() no lo recreaba, así
    // que tras un ciclo la recepción quedaba muerta para siempre.
    await t.start();
    final peer = LanTransport(port: 47922);
    await peer.start();
    final received = <Uint8List>[];
    final sub = t.onData.listen(received.add);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await peer.send(Uint8List.fromList([7, 7, 7]));
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (received.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await sub.cancel();
    await t.stop();
    await peer.stop();
    expect(received, isNotEmpty,
        reason: 'tras stop→start la recepción debe seguir viva');
  });
}
