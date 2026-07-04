import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/maps/composite_tile_provider.dart';
import 'package:prepper_pad/modules/maps/hybrid_tile_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

class FakeVectorProvider extends VectorTileProvider {
  FakeVectorProvider({
    required this.tiles,
    this.minZoom = 0,
    this.maxZoom = 15,
  });

  final Map<String, Uint8List> tiles;
  final int minZoom;
  final int maxZoom;

  static String key(TileIdentity tile) => '${tile.z}/${tile.x}/${tile.y}';

  @override
  int get minimumZoom => minZoom;

  @override
  int get maximumZoom => maxZoom;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    final data = tiles[key(tile)];
    if (data != null) return data;
    throw ProviderException(
      message: 'missing ${key(tile)}',
      retryable: Retryable.none,
      statusCode: 404,
    );
  }
}

void main() {
  test('CompositeTileProvider merges regions and falls through missing tiles',
      () async {
    final tile = TileIdentity(7, 42, 51);
    final expected = Uint8List.fromList([1, 2, 3]);
    final sourceA = FakeVectorProvider(tiles: {});
    final sourceB = FakeVectorProvider(
      tiles: {FakeVectorProvider.key(tile): expected},
      minZoom: 3,
      maxZoom: 13,
    );

    final composite = CompositeTileProvider.fromProviders([sourceA, sourceB]);

    expect(await composite.provide(tile), expected);
    expect(composite.minimumZoom, 0);
    expect(composite.maximumZoom, 15);
    expect(composite.length, 2);
  });

  test('CompositeTileProvider throws 404 when no source has the tile',
      () async {
    final composite = CompositeTileProvider.fromProviders([
      FakeVectorProvider(tiles: {}),
    ]);

    expect(
      () => composite.provide(TileIdentity(5, 1, 2)),
      throwsA(isA<ProviderException>()),
    );
  });

  test('HybridTileProvider uses online fallback only when offline misses',
      () async {
    final offlineTile = TileIdentity(6, 10, 12);
    final onlineTile = TileIdentity(6, 10, 13);
    final offlineBytes = Uint8List.fromList([9]);
    final onlineBytes = Uint8List.fromList([8]);
    final offline = CompositeTileProvider.fromProviders([
      FakeVectorProvider(
        tiles: {FakeVectorProvider.key(offlineTile): offlineBytes},
      ),
    ]);
    final online = FakeVectorProvider(
      tiles: {FakeVectorProvider.key(onlineTile): onlineBytes},
    );
    final hybrid = HybridTileProvider(offline, online);

    expect(await hybrid.provide(offlineTile), offlineBytes);
    expect(await hybrid.provide(onlineTile), onlineBytes);
  });
}
