// Hybrid tile provider: tries offline .pmtiles sources first, and if none
// has the tile, falls back to an online tile source (Protomaps demo server
// or any compatible vector tile endpoint) — so areas the user hasn't
// downloaded yet still appear when there's internet.
//
// When offline, the composite simply returns 404 for missing tiles and the
// renderer shows blank space, exactly as before.
import 'dart:typed_data';

import 'package:vector_map_tiles/vector_map_tiles.dart';

import 'composite_tile_provider.dart';

/// URL template for the online fallback. Protomaps' public demo server serves
/// free vector tiles (OpenStreetMap data) for development / light use.
/// Users who need heavy use can self-host or point this at a custom URL.
const kOnlineFallbackUrl = 'https://demo.protomaps.com/tiles/{z}/{x}/{y}.mvt';

/// Wraps a composite offline provider and adds an online fallback layer.
/// The online source is only tried when all offline sources miss the tile.
class HybridTileProvider extends VectorTileProvider {
  HybridTileProvider(this._offline, this._online);

  final CompositeTileProvider _offline;
  final VectorTileProvider _online;

  @override
  TileProviderType get type => TileProviderType.vector;

  @override
  int get maximumZoom => _offline.maximumZoom;

  @override
  int get minimumZoom => _offline.minimumZoom;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    // Try offline first.
    try {
      return await _offline.provide(tile);
    } on ProviderException catch (e) {
      if (e.statusCode != 404) rethrow;
    }
    // Fallback: try online. If it also fails (no internet), throw the 404
    // so the renderer shows blank space — silent degradation.
    try {
      return await _online.provide(tile);
    } on ProviderException catch (_) {
      throw ProviderException(
        message: 'Tile not found (offline + online): $tile',
        retryable: Retryable.none,
        statusCode: 404,
      );
    } on Exception {
      throw ProviderException(
        message: 'Tile not found (offline + no connection): $tile',
        retryable: Retryable.none,
        statusCode: 404,
      );
    }
  }
}
