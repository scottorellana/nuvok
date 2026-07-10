import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/transport_health.dart';

void main() {
  test('TransportHealth copyWith preserva y reemplaza campos', () {
    const h = TransportHealth(name: 'ble', state: TransportState.searching);
    expect(h.peers, 0);
    expect(h.hint, isNull);
    final h2 = h.copyWith(state: TransportState.connected, peers: 3);
    expect(h2.name, 'ble');
    expect(h2.state, TransportState.connected);
    expect(h2.peers, 3);
    // el original no cambia
    expect(h.state, TransportState.searching);
  });

  test('isBlocked identifica estados que necesitan acción del usuario', () {
    const off = TransportHealth(name: 'ble', state: TransportState.off);
    const perm =
        TransportHealth(name: 'ble', state: TransportState.noPermission);
    const ok = TransportHealth(name: 'lan', state: TransportState.searching);
    expect(off.isBlocked, isTrue);
    expect(perm.isBlocked, isTrue);
    expect(ok.isBlocked, isFalse);
  });
}
