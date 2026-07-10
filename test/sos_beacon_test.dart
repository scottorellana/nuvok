import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_envelope.dart';
import 'package:nuvok/modules/mesh/mesh_identity.dart';
import 'package:nuvok/modules/mesh/mesh_service.dart';
import 'package:nuvok/modules/mesh/mesh_transport.dart';
import 'package:nuvok/modules/tools/sos_beacon.dart';

class _Cap implements MeshTransport {
  final sent = <Uint8List>[];
  @override
  String get name => 'fake';
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List d) async => sent.add(d);
  @override
  Stream<Uint8List> get onData => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('estimación honesta de horas de beacon por batería', () {
    // Modelo conservador: ~4%/hora en modo solo-beacon.
    expect(sosBeaconHoursEstimate(100), 25.0);
    expect(sosBeaconHoursEstimate(40), 10.0);
    expect(sosBeaconHoursEstimate(0), 0.0);
    expect(sosBeaconHoursEstimate(-5), 0.0);
  });

  test('el burst final transmite y queda registrado en disco', () async {
    final dir = Directory.systemTemp.createTempSync('burst').path;
    final t = _Cap();
    final svc = MeshService.forTest(
      dirPath: dir,
      transports: [t],
      identity: MeshIdentity.create('Baliza'),
    );
    await svc.start();

    final ok = await svc.sendLastPositionBurst(
        lat: 15.5, lon: -88.0, note: 'batería crítica');
    expect(ok, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final sos = t.sent
        .map(MeshEnvelope.decode)
        .whereType<MeshEnvelope>()
        .where((e) => e.type == MeshType.sos);
    expect(sos, isNotEmpty, reason: 'el burst sale como SOS con posición');

    // Registro en disco para rescatistas que recuperen el teléfono.
    final f = File('$dir/last_position.json');
    expect(f.existsSync(), isTrue);
    expect(f.readAsStringSync(), contains('15.5'));
    await svc.stop();
  });
}
