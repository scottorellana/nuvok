import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_power_controller.dart';

/// Que la política decida bien no sirve de nada si la decisión no llega a la
/// radio. Esto verifica el otro extremo: lo que sale por el MethodChannel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('nuvok/ble_mesh');
  final calls = <Map<Object?, Object?>>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setPowerMode') {
        calls.add(call.arguments as Map<Object?, Object?>);
      }
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('el plan de anuncio viaja junto al de escaneo', () async {
    final ctrl = MeshPowerController.instance;
    ctrl.setSosActive(true);
    await Future<void>.delayed(Duration.zero);

    expect(calls, isNotEmpty, reason: 'no se avisó a la radio del cambio');
    final last = calls.last;
    expect(last['advertiseMode'], isNotNull,
        reason: 'sin esto Kotlin se queda con los ajustes del arranque');
    expect(last['advertiseMode'], 'lowLatency');
    expect(last['advertiseTxPower'], 'high',
        reason: 'con un SOS en curso el alcance manda sobre la batería');

    ctrl.setSosActive(false);
    await Future<void>.delayed(Duration.zero);
  });
}
