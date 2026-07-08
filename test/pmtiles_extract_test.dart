import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pmtiles/pmtiles.dart' as pm;
import 'package:prepper_pad/modules/depot/pmtiles_extract_dart.dart';

// El extractor client-side es LO que permite descargar mapas por país en un
// iPhone/Android de producción sin servidores propios: recorta la región del
// build mundial de Protomaps con range-requests. Se valida con round-trip
// contra el lector independiente del paquete `pmtiles`.
void main() {
  // Un origen sintético: mundo z0..z3, cada tile con payload reconocible.
  // maxZoom bajo mantiene el test en milisegundos.
  late File source;
  late Directory tmp;

  Uint8List payloadFor(int z, int x, int y) =>
      Uint8List.fromList('tile:$z/$x/$y'.codeUnits);

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('pmx');
    source = File('${tmp.path}/world.pmtiles');
    final entries = <PmEntry>[];
    final blobs = <Uint8List>[];
    var offset = 0;
    for (var z = 0; z <= 3; z++) {
      for (var x = 0; x < (1 << z); x++) {
        for (var y = 0; y < (1 << z); y++) {
          final data = payloadFor(z, x, y);
          entries.add(PmEntry(
              tileId: zxyToTileId(z, x, y),
              offset: offset,
              length: data.length,
              runLength: 1));
          blobs.add(data);
          offset += data.length;
        }
      }
    }
    entries.sort((a, b) => a.tileId.compareTo(b.tileId));
    await writePmTiles(
      dest: source,
      entries: entries,
      dataBlobs: blobs,
      metadataJson: '{"name":"synthetic"}',
      minZoom: 0,
      maxZoom: 3,
      tileType: 1,
      tileCompression: 1, // none: payloads van tal cual
      boundsE7: const [-1800000000, -850000000, 1800000000, 850000000],
    );
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('el origen sintético lo abre el lector independiente', () async {
    final a = await pm.PmTilesArchive.fromFile(source);
    final t = await a.tile(zxyToTileId(2, 1, 1));
    expect(Uint8List.fromList(t.bytes()), payloadFor(2, 1, 1));
    await a.close();
  });

  test('extraer un bbox produce un pmtiles válido con solo esa región',
      () async {
    final dest = File('${tmp.path}/west.pmtiles');
    // Hemisferio oeste-norte aproximado: x=0 en z1 → lon -180..0, lat 0..85.
    final log = <String>[];
    await extractPmTiles(
      source: FileRangeSource(source),
      dest: dest,
      west: -179,
      south: 1,
      east: -1,
      north: 84,
      onProgress: (m, _) => log.add(m),
    );
    expect(dest.existsSync(), isTrue);
    expect(dest.lengthSync(), lessThan(source.lengthSync()));

    final a = await pm.PmTilesArchive.fromFile(dest);
    // Dentro del bbox: z1 (0,0); z2 (0,0),(1,1); z0 raíz siempre va.
    expect(Uint8List.fromList((await a.tile(zxyToTileId(0, 0, 0))).bytes()),
        payloadFor(0, 0, 0));
    expect(Uint8List.fromList((await a.tile(zxyToTileId(1, 0, 0))).bytes()),
        payloadFor(1, 0, 0));
    expect(Uint8List.fromList((await a.tile(zxyToTileId(2, 1, 1))).bytes()),
        payloadFor(2, 1, 1));
    // Fuera del bbox (hemisferio este): no debe existir. El lector devuelve
    // el Tile y lanza recién al pedir los bytes.
    final missing = await a.tile(zxyToTileId(1, 1, 0));
    expect(() => missing.bytes(), throwsA(isA<pm.TileNotFoundException>()));
    await a.close();
  });

  test('maxZoom recorta niveles profundos', () async {
    final dest = File('${tmp.path}/z1.pmtiles');
    await extractPmTiles(
      source: FileRangeSource(source),
      dest: dest,
      west: -179,
      south: -84,
      east: 179,
      north: 84,
      maxZoom: 1,
    );
    final a = await pm.PmTilesArchive.fromFile(dest);
    expect(Uint8List.fromList((await a.tile(zxyToTileId(1, 1, 1))).bytes()),
        payloadFor(1, 1, 1));
    final deep = await a.tile(zxyToTileId(3, 0, 0));
    expect(() => deep.bytes(), throwsA(isA<pm.TileNotFoundException>()));
    await a.close();
  });

  test('extract real desde el fixture El Salvador (bbox de San Salvador)',
      () async {
    final fixture =
        File('assets/bundled_library/maps/el-salvador.pmtiles');
    if (!fixture.existsSync()) {
      markTestSkipped('fixture local no presente');
      return;
    }
    final dest = File('${tmp.path}/san-salvador.pmtiles');
    await extractPmTiles(
      source: FileRangeSource(fixture),
      dest: dest,
      west: -89.35,
      south: 13.55,
      east: -89.05,
      north: 13.85,
      maxZoom: 12,
    );
    final a = await pm.PmTilesArchive.fromFile(dest);
    // El centro de San Salvador a z12 debe tener tile con datos.
    // lon -89.19, lat 13.69 → x,y slippy z12.
    final x = lonToTileX(-89.19, 12), y = latToTileY(13.69, 12);
    final t = await a.tile(zxyToTileId(12, x, y));
    expect(t.bytes().length, greaterThan(0));
    await a.close();
    expect(dest.lengthSync(), lessThan(20 * 1024 * 1024),
        reason: 'un recorte urbano z12 debe ser chico');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
