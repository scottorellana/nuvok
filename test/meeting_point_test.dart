import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nuvok/modules/maps/map_overlays.dart';
import 'package:nuvok/modules/maps/meeting_point.dart';
import 'package:nuvok/modules/mesh/position_store.dart';

PeerPosition _p(String name, double lat, double lon) => PeerPosition(
    id: name, name: name, lat: lat, lon: lon, time: DateTime(2026, 7, 9));

void main() {
  final point = MapOverlay(
    id: 'mp1',
    kind: OverlayKind.meetingPoint,
    points: [const LatLng(15.5000, -88.0000)],
    name: 'Parque central',
  );

  test('separa llegados de faltantes según el radio', () {
    final positions = [
      _p('Ana', 15.5001, -88.0001), // ~15 m → llegó
      _p('Luis', 15.5100, -88.0100), // >1 km → falta
    ];
    final st = meetingStatus(point, positions);
    expect(st.arrived.map((p) => p.name), ['Ana']);
    expect(st.pending.map((p) => p.name), ['Luis']);
  });

  test('activeMeetingPoint encuentra el primero y tolera listas sin punto',
      () {
    expect(activeMeetingPoint([]), isNull);
    final other = MapOverlay(
        id: 'x', kind: OverlayKind.water, points: [const LatLng(0, 0)]);
    expect(activeMeetingPoint([other, point])?.id, 'mp1');
  });
}
