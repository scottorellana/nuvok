// Composite tile provider: merges multiple .pmtiles archives into a single
// virtual surface so the user can pan across regions as if they were one —
// exactly like Google Maps shows all downloaded areas in a single view.
//
// Each tile request is tried against every source in order. The first source
// that has data for that tile wins; missing tiles fall through silently. If
// no source has the tile, a ProviderException (404, not-retryable) is thrown
// so flutter_map renders blank space — consistent with a single-source map.
import 'dart:typed_data';

import 'package:vector_map_tiles/vector_map_tiles.dart';

/// A single source inside the composite, with an optional human-readable
/// label for debugging.
class _Source {
  _Source(this.label, this.provider);
  final String label;
  final VectorTileProvider provider;
}

class CompositeTileProvider extends VectorTileProvider {
  CompositeTileProvider(this._sources);

  final List<_Source> _sources;

  /// Builds a composite from a list of already-opened providers.
  static CompositeTileProvider fromProviders(List<VectorTileProvider> providers) {
    return CompositeTileProvider(
      [for (var i = 0; i < providers.length; i++) _Source('source-$i', providers[i])],
    );
  }

  @override
  TileProviderType get type => TileProviderType.vector;

  @override
  int get maximumZoom {
    if (_sources.isEmpty) return 15;
    return _sources
        .map((s) => s.provider.maximumZoom)
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  int get minimumZoom {
    if (_sources.isEmpty) return 0;
    return _sources
        .map((s) => s.provider.minimumZoom)
        .reduce((a, b) => a < b ? a : b);
  }

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    for (final src in _sources) {
      try {
        final data = await src.provider.provide(tile);
        return data;
      } on ProviderException catch (e) {
        // Tile not in this source — try the next one.
        if (e.statusCode == 404) continue;
        rethrow;
      }
    }
    // No source has this tile — tell the renderer it's not available.
    throw ProviderException(
      message: 'Tile not found in any source: $tile',
      retryable: Retryable.none,
      statusCode: 404,
    );
  }

  /// Number of underlying sources.
  int get length => _sources.length;
  bool get isEmpty => _sources.isEmpty;
}
