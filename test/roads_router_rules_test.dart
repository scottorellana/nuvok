import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:prepper_pad/modules/maps/roads_router.dart';

// Reglas puras de ruteo por perfil: qué aristas se permiten, con qué peso,
// y cómo afectan portones y zonas de riesgo. Sin .pmtiles — unit tests.
void main() {
  group('edgeMultiplier', () {
    test('calle privada queda excluida en ambos perfiles', () {
      const a = EdgeAttrs(kindDetail: 'residential', access: 'private');
      expect(RoadRouter.edgeMultiplier(a, RouteProfile.vehicle), isNull);
      expect(RoadRouter.edgeMultiplier(a, RouteProfile.walk), isNull);
    });

    test('access=no queda excluida', () {
      const a = EdgeAttrs(kindDetail: 'service', access: 'no');
      expect(RoadRouter.edgeMultiplier(a, RouteProfile.vehicle), isNull);
    });

    test('peatonales excluidas en vehículo, permitidas a pie', () {
      for (final kd in [
        'footway',
        'steps',
        'path',
        'pedestrian',
        'sidewalk',
        'crossing'
      ]) {
        final a = EdgeAttrs(kindDetail: kd);
        expect(RoadRouter.edgeMultiplier(a, RouteProfile.vehicle), isNull,
            reason: '$kd debe excluirse en vehículo');
        expect(RoadRouter.edgeMultiplier(a, RouteProfile.walk), 1.0,
            reason: '$kd debe permitirse a pie');
      }
    });

    test('track penalizada x3 en vehículo, normal a pie', () {
      const a = EdgeAttrs(kindDetail: 'track');
      expect(RoadRouter.edgeMultiplier(a, RouteProfile.vehicle), 3.0);
      expect(RoadRouter.edgeMultiplier(a, RouteProfile.walk), 1.0);
    });

    test('residential normal en ambos', () {
      const a = EdgeAttrs(kindDetail: 'residential');
      expect(RoadRouter.edgeMultiplier(a, RouteProfile.vehicle), 1.0);
      expect(RoadRouter.edgeMultiplier(a, RouteProfile.walk), 1.0);
    });
  });

  group('oneway', () {
    test('bloquea la reversa solo en vehículo', () {
      const a = EdgeAttrs(kindDetail: 'primary', oneway: true);
      expect(RoadRouter.onewayBlocksReverse(a, RouteProfile.vehicle), isTrue);
      expect(RoadRouter.onewayBlocksReverse(a, RouteProfile.walk), isFalse);
    });

    test('sin oneway no bloquea', () {
      const a = EdgeAttrs(kindDetail: 'primary');
      expect(RoadRouter.onewayBlocksReverse(a, RouteProfile.vehicle), isFalse);
    });
  });

  group('portones (barriers)', () {
    // ~15 m ≈ 0.000135° de latitud.
    const barrier = LatLng(15.5000, -88.0000);
    test('arista con extremo a <15m del portón se corta', () {
      const nearA = LatLng(15.50008, -88.0000); // ~9 m
      const b = LatLng(15.5010, -88.0000);
      expect(RoadRouter.nearAnyBarrier(nearA, b, const [barrier]), isTrue);
    });
    test('arista con punto medio sobre el portón se corta', () {
      const a = LatLng(15.49990, -88.0000);
      const b = LatLng(15.50010, -88.0000); // medio ≈ barrier
      expect(RoadRouter.nearAnyBarrier(a, b, const [barrier]), isTrue);
    });
    test('arista lejana no se corta', () {
      const a = LatLng(15.5030, -88.0000); // ~330 m
      const b = LatLng(15.5040, -88.0000);
      expect(RoadRouter.nearAnyBarrier(a, b, const [barrier]), isFalse);
    });
  });

  group('zonas de riesgo', () {
    const zone = [
      LatLng(15.50, -88.01),
      LatLng(15.51, -88.01),
      LatLng(15.51, -88.00),
      LatLng(15.50, -88.00),
    ];
    test('punto dentro del polígono', () {
      expect(
          RoadRouter.insideAnyZone(const LatLng(15.505, -88.005), const [zone]),
          isTrue);
    });
    test('punto fuera del polígono', () {
      expect(
          RoadRouter.insideAnyZone(const LatLng(15.52, -88.005), const [zone]),
          isFalse);
    });
  });

  group('RouteRestrictions', () {
    test('constructor por defecto vacío', () {
      const r = RouteRestrictions();
      expect(r.barriers, isEmpty);
      expect(r.riskZones, isEmpty);
    });
  });
}
