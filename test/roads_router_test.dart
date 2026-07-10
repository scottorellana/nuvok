import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nuvok/modules/maps/roads_router.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

// Probes street routing on the real Honduras map. Skipped on CI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final home = Platform.environment['HOME']!;
  final path = '$home/Nuvok/maps/honduras.pmtiles';

  test('calcula una ruta por calles entre dos puntos de San Pedro Sula',
      () async {
    if (!File(path).existsSync()) {
      markTestSkipped('honduras.pmtiles no está presente');
      return;
    }
    final provider = await PmTilesVectorTileProvider.fromSource(path);
    // Dos puntos dentro de San Pedro Sula (~2-3 km aparte).
    const origin = LatLng(15.505, -88.025);
    const destination = LatLng(15.495, -88.010);
    final outcome = await RoadRouter.route(
      provider: provider,
      origin: origin,
      destination: destination,
      zoom: 15,
    );
    // ignore: avoid_print
    print('estado: ${outcome.status}');
    if (outcome.result != null) {
      final r = outcome.result!;
      // ignore: avoid_print
      print('ruta: ${r.path.length} puntos, '
          '${(r.distanceMeters / 1000).toStringAsFixed(2)} km');
    }
    expect(outcome.status, RouteStatus.ok);
    final r = outcome.result!;
    expect(r.path.length, greaterThan(3));
    // La ruta por calles debe ser más larga que la línea recta pero no
    // absurdamente (indicador de que sigue calles reales).
    const straight = Distance();
    final crow = straight(origin, destination);
    expect(r.distanceMeters, greaterThanOrEqualTo(crow));
    expect(r.distanceMeters, lessThan(crow * 4));
  });
}
