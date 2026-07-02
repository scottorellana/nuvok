import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

// Probes the Honduras PMTiles extract end-to-end. Skipped when the map file
// is not present (e.g. on CI).
void main() {
  final home = Platform.environment['HOME']!;
  final path = '$home/PrepperPad/maps/honduras.pmtiles';

  (int, int) tileXY(double lat, double lon, int z) {
    final n = 1 << z;
    final x = ((lon + 180) / 360 * n).floor();
    final latRad = lat * math.pi / 180;
    final y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2 *
                n)
            .floor();
    return (x, y);
  }

  test('provee y decodifica tiles de Honduras en varios zooms', () async {
    if (!File(path).existsSync()) {
      markTestSkipped('honduras.pmtiles no está presente');
      return;
    }
    final provider = await PmTilesVectorTileProvider.fromSource(path);
    for (final z in [7, 10, 12, 14]) {
      final (x, y) = tileXY(14.0723, -87.1921, z); // Tegucigalpa
      final bytes = await provider.provide(TileIdentity(z, x, y));
      final gzip = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
      final tile = vtr.TileFactory(
              ProtomapsThemes.lightV4(), const vtr.Logger.noop())
          .create(vtr.VectorTileReader().read(bytes));
      expect(bytes.length, greaterThan(0));
      expect(gzip, isFalse, reason: 'tile z$z llegó comprimido (gzip)');
      expect(tile.layers, isNotEmpty);
    }
  });

  test('provee 12 tiles CONCURRENTES como hace el widget del mapa', () async {
    if (!File(path).existsSync()) {
      markTestSkipped('honduras.pmtiles no está presente');
      return;
    }
    final provider = await PmTilesVectorTileProvider.fromSource(path);
    const z = 10;
    final (cx, cy) = tileXY(14.0723, -87.1921, z);
    final futures = <Future<void>>[];
    for (var dx = -2; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        futures.add(
          provider.provide(TileIdentity(z, cx + dx, cy + dy)).then((b) {
            expect(b.length, greaterThan(0));
          }),
        );
      }
    }
    await Future.wait(futures);
  });
}
