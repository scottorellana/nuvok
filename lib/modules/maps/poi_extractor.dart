// Extracts points of interest (hospitals, pharmacies, fuel, stores, …)
// straight from the offline .pmtiles the user already downloaded. The
// Protomaps basemap ships a `pois` vector layer whose features carry a
// `kind` (e.g. "hospital") and a `name`; we decode the covering tiles and
// convert tile-local coordinates to lat/lng. No extra data, works anywhere
// the user has a map.
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile/vector_tile.dart';

/// Nuvok-relevant POI categories, each mapping to the raw Protomaps
/// `kind` values that belong to it.
enum PoiCategory { health, pharmacy, fuel, food, safety, water }

const Map<PoiCategory, Set<String>> kPoiKinds = {
  PoiCategory.health: {'hospital', 'clinic', 'doctors'},
  PoiCategory.pharmacy: {'pharmacy', 'chemist'},
  PoiCategory.fuel: {'fuel'},
  PoiCategory.food: {
    'supermarket',
    'grocery',
    'convenience',
    'marketplace',
    'greengrocer',
  },
  PoiCategory.safety: {'fire_station', 'police'},
  PoiCategory.water: {'drinking_water', 'water_point', 'spring'},
};

PoiCategory? categoryForKind(String kind) {
  for (final entry in kPoiKinds.entries) {
    if (entry.value.contains(kind)) return entry.key;
  }
  return null;
}

class MapPoi {
  MapPoi({
    required this.location,
    required this.kind,
    required this.category,
    this.name,
  });

  final LatLng location;
  final String kind;
  final PoiCategory category;
  final String? name;
}

class PoiExtractor {
  /// Extracts POIs of the requested [categories] within [bounds]. Reads the
  /// `pois` layer from the tiles covering the view at [zoom] (clamped to the
  /// map's max zoom). Deduplicates by rounded location + name.
  static Future<List<MapPoi>> extract({
    required VectorTileProvider provider,
    required LatLngBounds bounds,
    required int zoom,
    required Set<PoiCategory> categories,
    int maxTiles = 64,
  }) async {
    if (categories.isEmpty) return [];
    final wantedKinds = <String>{
      for (final c in categories) ...kPoiKinds[c]!,
    };
    // POIs only appear in the data from ~z13; clamp into a useful band.
    final z = zoom.clamp(13, provider.maximumZoom);
    final (minX, maxY) = _tileXY(bounds.south, bounds.west, z);
    final (maxX, minY) = _tileXY(bounds.north, bounds.east, z);

    final results = <MapPoi>[];
    final seen = <String>{};
    var tilesRead = 0;
    for (var tx = minX; tx <= maxX; tx++) {
      for (var ty = minY; ty <= maxY; ty++) {
        if (tilesRead >= maxTiles) return results;
        tilesRead++;
        try {
          final bytes = await provider.provide(TileIdentity(z, tx, ty));
          if (bytes.isEmpty) continue;
          final tile = VectorTile.fromBytes(bytes: bytes);
          for (final layer in tile.layers) {
            if (layer.name != 'pois') continue;
            final extent = layer.extent.toDouble();
            for (final f in layer.features) {
              final props = f.decodeProperties();
              final kind = props['kind']?.dartStringValue;
              if (kind == null || !wantedKinds.contains(kind)) continue;
              final cat = categoryForKind(kind);
              if (cat == null) continue;
              final coords = _pointCoords(f);
              if (coords == null) continue;
              final ll =
                  _tilePointToLatLng(tx, ty, z, coords.$1, coords.$2, extent);
              final name = props['name']?.dartStringValue;
              final key = '${ll.latitude.toStringAsFixed(5)},'
                  '${ll.longitude.toStringAsFixed(5)},${name ?? kind}';
              if (!seen.add(key)) continue;
              results.add(MapPoi(
                location: ll,
                kind: kind,
                category: cat,
                name: name,
              ));
            }
          }
        } catch (_) {
          // Missing/edge tile — skip.
        }
      }
    }
    return results;
  }

  /// First point coordinate (tile-extent space) of a point/multipoint feature.
  static (double, double)? _pointCoords(VectorTileFeature f) {
    try {
      final geom = f.decodeGeometry();
      if (geom is GeometryPoint) {
        final c = geom.coordinates;
        return (c[0].toDouble(), c[1].toDouble());
      }
      if (geom is GeometryMultiPoint) {
        final c = geom.coordinates.first;
        return (c[0].toDouble(), c[1].toDouble());
      }
    } catch (_) {}
    return null;
  }

  static (int, int) _tileXY(double lat, double lon, int z) {
    final n = 1 << z;
    final x = ((lon + 180) / 360 * n).floor().clamp(0, n - 1);
    final latRad = lat * math.pi / 180;
    final y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2 *
                n)
            .floor()
            .clamp(0, n - 1);
    return (x, y);
  }

  static LatLng _tilePointToLatLng(
      int tx, int ty, int z, double px, double py, double extent) {
    final n = (1 << z).toDouble();
    final worldX = tx + px / extent;
    final worldY = ty + py / extent;
    final lon = worldX / n * 360 - 180;
    final latRad = math.atan(_sinh(math.pi * (1 - 2 * worldY / n)));
    return LatLng(latRad * 180 / math.pi, lon);
  }

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
}
