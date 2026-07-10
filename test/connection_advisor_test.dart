import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/connection_advisor.dart';
import 'package:nuvok/modules/mesh/transport_health.dart';

TransportHealth _h(String name, TransportState s, {int peers = 0}) =>
    TransportHealth(name: name, state: s, peers: peers);

void main() {
  test('con pares conectados no hay pasos', () {
    final steps = ConnectionAdvisor.advise(
      healths: [_h('ble', TransportState.connected, peers: 2)],
      platform: TargetPlatform.android,
      searching: const Duration(seconds: 60),
    );
    expect(steps, isEmpty);
  });

  test('bluetooth apagado es el primer paso', () {
    final steps = ConnectionAdvisor.advise(
      healths: [
        _h('ble', TransportState.off),
        _h('lan', TransportState.searching),
      ],
      platform: TargetPlatform.iOS,
      searching: const Duration(seconds: 5),
    );
    expect(steps.first.kind, AdvisorStepKind.bluetoothOff);
  });

  test('permiso denegado sugiere ajustes de la app', () {
    final steps = ConnectionAdvisor.advise(
      healths: [_h('ble', TransportState.noPermission)],
      platform: TargetPlatform.iOS,
      searching: const Duration(seconds: 5),
    );
    expect(steps.first.kind, AdvisorStepKind.bluetoothPermission);
  });

  test('todo bien pero solo tras 30s propone hotspot y LoRa al final', () {
    final early = ConnectionAdvisor.advise(
      healths: [
        _h('ble', TransportState.searching),
        _h('lan', TransportState.searching),
      ],
      platform: TargetPlatform.android,
      searching: const Duration(seconds: 10),
    );
    expect(early.any((s) => s.kind == AdvisorStepKind.hotspot), isFalse);

    final late = ConnectionAdvisor.advise(
      healths: [
        _h('ble', TransportState.searching),
        _h('lan', TransportState.searching),
      ],
      platform: TargetPlatform.android,
      searching: const Duration(seconds: 45),
    );
    expect(late.any((s) => s.kind == AdvisorStepKind.hotspot), isTrue);
    // LoRa siempre es el último recurso informativo tras 30s
    expect(late.last.kind, AdvisorStepKind.lora);
  });

  test('sin red LAN el hint acelera la sugerencia de hotspot', () {
    final steps = ConnectionAdvisor.advise(
      healths: [
        _h('ble', TransportState.searching),
        const TransportHealth(
            name: 'lan',
            state: TransportState.unavailable,
            hint: 'no_network'),
      ],
      platform: TargetPlatform.android,
      searching: const Duration(seconds: 5),
    );
    expect(steps.any((s) => s.kind == AdvisorStepKind.hotspot), isTrue);
  });
}
