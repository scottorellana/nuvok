import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:prepper_pad/modules/maps/maps_page.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

// Renders one Tegucigalpa tile to a PNG on disk so we can see exactly what
// the style engine produces, bypassing the flutter_map widget stack.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final home = Platform.environment['HOME']!;
  final path = '$home/PrepperPad/maps/honduras.pmtiles';

  test('renderiza un tile z12 de Tegucigalpa a PNG', () async {
    if (!File(path).existsSync()) {
      markTestSkipped('honduras.pmtiles no está presente');
      return;
    }
    final provider = await PmTilesVectorTileProvider.fromSource(path);
    const z = 12;
    const lat = 14.0723, lon = -87.1921;
    final n = 1 << z;
    final x = ((lon + 180) / 360 * n).floor();
    final latRad = lat * math.pi / 180;
    final y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2 *
                n)
            .floor();
    final bytes = await provider.provide(TileIdentity(z, x, y));
    final theme = await loadMapTheme();
    final tile = vtr.TileFactory(theme, const vtr.Logger.noop())
        .create(vtr.VectorTileReader().read(bytes));

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    vtr.Renderer(theme: theme).render(
      canvas,
      vtr.TileSource(tileset: vtr.Tileset({'protomaps': tile})),
      zoomScaleFactor: 1,
      zoom: z.toDouble(),
      rotation: 0,
      clip: null,
    );
    final image = await recorder.endRecording().toImage(512, 512);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('/tmp/tile_probe.png');
    await out.writeAsBytes(png!.buffer.asUint8List());
    // ignore: avoid_print
    print('PNG escrito: ${out.path} (${out.lengthSync()} bytes)');
    expect(out.lengthSync(), greaterThan(1000));
  });
}
