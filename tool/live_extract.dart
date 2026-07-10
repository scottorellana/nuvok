import 'dart:io';
import 'package:pmtiles/pmtiles.dart' as pm;
import 'package:nuvok/modules/depot/pmtiles_extract_dart.dart';

Future<void> main() async {
  final dest = File('/tmp/belize.pmtiles');
  final sw = Stopwatch()..start();
  await extractPmTiles(
    source: HttpRangeSource(
        Uri.parse('https://build.protomaps.com/20260708.pmtiles')),
    dest: dest,
    west: -89.3, south: 15.8, east: -87.4, north: 18.5, // Belize
    maxZoom: 12,
    onProgress: (m, f) => stdout.writeln('  $m'),
  );
  sw.stop();
  stdout.writeln(
    'tiempo: ${sw.elapsed.inSeconds}s, '
    'tamaño: ${(dest.lengthSync() / 1048576).toStringAsFixed(1)} MB',
  );
  final a = await pm.PmTilesArchive.fromFile(dest);
  final x = lonToTileX(-88.19, 12), y = latToTileY(17.5, 12); // Belmopan
  final t = await a.tile(zxyToTileId(12, x, y));
  stdout.writeln('tile Belmopan z12: ${t.bytes().length} bytes → VISOR OK');
  await a.close();
}
