import 'dart:io';

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:prepper_pad/modules/maps/poi_extractor.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

// Probes POI extraction against the real Honduras map. Skipped on CI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final home = Platform.environment['HOME']!;
  final path = '$home/PrepperPad/maps/honduras.pmtiles';

  test('extrae POIs reales (hospitales, farmacias, tiendas) del .pmtiles',
      () async {
    if (!File(path).existsSync()) {
      markTestSkipped('honduras.pmtiles no está presente');
      return;
    }
    final provider = await PmTilesVectorTileProvider.fromSource(path);
    // Área amplia sobre San Pedro Sula / valle de Sula.
    final bounds = LatLngBounds(
      const LatLng(15.60, -88.10),
      const LatLng(15.45, -87.95),
    );
    final pois = await PoiExtractor.extract(
      provider: provider,
      bounds: bounds,
      zoom: 14,
      categories: PoiCategory.values.toSet(),
    );
    // Print what kinds actually exist so we can tune the UI.
    final byCat = <PoiCategory, int>{};
    for (final p in pois) {
      byCat[p.category] = (byCat[p.category] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('POIs encontrados: ${pois.length} → $byCat');
    // ignore: avoid_print
    print(
        'Ejemplos: ${pois.take(8).map((p) => '${p.kind}:${p.name}').toList()}');
    expect(pois, isNotEmpty,
        reason: 'el mapa debería contener al menos algunos POIs');
  });
}
