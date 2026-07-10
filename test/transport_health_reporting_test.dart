import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/lan_transport.dart';
import 'package:nuvok/modules/mesh/transport_health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LanTransport: unavailable → searching al start → unavailable al stop',
      () async {
    final t = LanTransport(port: 47799); // puerto de prueba, sin deviceId
    expect(t.health.value.state, TransportState.unavailable);
    await t.start();
    expect(t.health.value.state, TransportState.searching);
    await t.stop();
    expect(t.health.value.state, TransportState.unavailable);
  });
}
