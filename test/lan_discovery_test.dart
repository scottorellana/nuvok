import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/lan_discovery.dart';

// Bonjour discovery glue: platform plumbing (bonsoir) can't run in a unit
// test, so the resolution logic is exercised directly — it must seed unicast
// peers and never feed our own announcement back to us.
void main() {
  test('un servicio resuelto ajeno dispara onPeer con ip y puerto', () {
    final seen = <(String, int)>[];
    final d = LanDiscovery(
      deviceId: 'yo',
      port: 47777,
      onPeer: (ip, port) => seen.add((ip, port)),
    );
    d.handleResolved(id: 'otro', ip: '192.168.1.7', port: 47777);
    d.handleResolved(id: 'yo', ip: '192.168.1.5', port: 47777); // yo mismo
    expect(seen, [('192.168.1.7', 47777)]);
  });

  test('datos incompletos o inválidos se ignoran sin reventar', () {
    final seen = <(String, int)>[];
    final d = LanDiscovery(
      deviceId: 'yo',
      port: 47777,
      onPeer: (ip, port) => seen.add((ip, port)),
    );
    d.handleResolved(id: '', ip: '192.168.1.9', port: 47777);
    d.handleResolved(id: 'x', ip: '', port: 47777);
    d.handleResolved(id: 'x', ip: '192.168.1.9', port: 0);
    expect(seen, isEmpty);
  });

  test('el mismo peer resuelto dos veces solo avisa una vez', () {
    final seen = <(String, int)>[];
    final d = LanDiscovery(
      deviceId: 'yo',
      port: 47777,
      onPeer: (ip, port) => seen.add((ip, port)),
    );
    d.handleResolved(id: 'otro', ip: '192.168.1.7', port: 47777);
    d.handleResolved(id: 'otro', ip: '192.168.1.7', port: 47777);
    expect(seen, hasLength(1));
    // Pero si cambia de IP (DHCP), sí vuelve a avisar.
    d.handleResolved(id: 'otro', ip: '192.168.1.20', port: 47777);
    expect(seen, hasLength(2));
  });
}
