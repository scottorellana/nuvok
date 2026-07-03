import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:prepper_pad/modules/maps/map_overlays.dart';

// Verifies overlays survive a GeoJSON round-trip (persistence format).
void main() {
  test('punto personalizado round-trips a GeoJSON', () {
    final o = MapOverlay(
      id: '1',
      kind: OverlayKind.shelter,
      points: [const LatLng(15.5, -88.0)],
      name: 'Refugio Norte',
    );
    final back = MapOverlay.fromFeature(o.toFeature())!;
    expect(back.kind, OverlayKind.shelter);
    expect(back.name, 'Refugio Norte');
    expect(back.anchor.latitude, closeTo(15.5, 1e-9));
    expect(back.anchor.longitude, closeTo(-88.0, 1e-9));
  });

  test('zona de riesgo (polígono) round-trips con nivel de peligro', () {
    final o = MapOverlay(
      id: '2',
      kind: OverlayKind.riskZone,
      points: const [
        LatLng(15.5, -88.0),
        LatLng(15.6, -88.0),
        LatLng(15.6, -87.9),
      ],
      dangerLevel: 4,
    );
    final f = o.toFeature();
    expect(f['geometry']['type'], 'Polygon');
    // GeoJSON polygon ring must be closed.
    final ring = (f['geometry']['coordinates'] as List).first as List;
    expect(ring.first, ring.last);
    final back = MapOverlay.fromFeature(f)!;
    expect(back.kind, OverlayKind.riskZone);
    expect(back.dangerLevel, 4);
    expect(back.points.length, 3); // closing dup removed
  });

  test('ruta de evacuación (línea) round-trips', () {
    final o = MapOverlay(
      id: '3',
      kind: OverlayKind.evacuationRoute,
      points: const [LatLng(15.5, -88.0), LatLng(15.55, -88.05)],
    );
    final f = o.toFeature();
    expect(f['geometry']['type'], 'LineString');
    final back = MapOverlay.fromFeature(f)!;
    expect(back.kind, OverlayKind.evacuationRoute);
    expect(back.points.length, 2);
  });
}
