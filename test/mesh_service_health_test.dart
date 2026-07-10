import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_identity.dart';
import 'package:nuvok/modules/mesh/mesh_service.dart';
import 'package:nuvok/modules/mesh/mesh_transport.dart';
import 'package:nuvok/modules/mesh/transport_health.dart';

class _HealthyFake implements MeshTransport, HealthReporting {
  @override
  final String name = 'ble';
  @override
  final ValueNotifier<TransportHealth> health = ValueNotifier(
      const TransportHealth(name: 'ble', state: TransportState.searching));
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List datagram) async {}
  @override
  Stream<Uint8List> get onData => const Stream.empty();
}

class _MuteFake implements MeshTransport {
  @override
  final String name = 'lora';
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List datagram) async {}
  @override
  Stream<Uint8List> get onData => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('transportHealths refleja transportes con y sin HealthReporting',
      () async {
    final dir = Directory.systemTemp.createTempSync('meshsvc').path;
    final svc = MeshService.forTest(
      dirPath: dir,
      transports: [_HealthyFake(), _MuteFake()],
      identity: MeshIdentity.create('Test'),
    );
    await svc.start();
    final healths = svc.transportHealths.value;
    expect(healths, hasLength(2));
    expect(healths.firstWhere((h) => h.name == 'ble').state,
        TransportState.searching);
    // El transporte sin HealthReporting aparece como searching genérico
    // (está arrancado) para que el asistente lo cuente.
    expect(healths.firstWhere((h) => h.name == 'lora').state,
        TransportState.searching);
    await svc.stop();
  });
}
