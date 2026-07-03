// Offline place search over the loaded .pmtiles: decodes the `places` layer
// (cities, towns) once per map file and keeps an in-memory index, so the user
// can type "San Pedro" and be taken (and routed) straight there — no
// geocoding service involved.
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile/vector_tile.dart';

class PlaceEntry {
  PlaceEntry({required this.name, required this.kind, required this.location});
  final String name;
  final String kind; // locality, town, village, region…
  final LatLng location;
}

class PlaceIndex {
  PlaceIndex._(this.entries);
  final List<PlaceEntry> entries;

  static final Map<String, PlaceIndex> _cache = {};

  /// Builds (or returns cached) index for the map identified by [cacheKey].
  /// Probes z4 for populated tiles, then reads their z8 descendants — a
  /// country map needs a few hundred cheap local reads, once.
  static Future<PlaceIndex> forProvider(
    VectorTileProvider provider,
    String cacheKey, {
    int maxTiles = 1600,
  }) async {
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final entries = <PlaceEntry>[];
    final seen = <String>{};
    var reads = 0;

    Future<void> scanTile(int z, int x, int y) async {
      if (reads >= maxTiles) return;
      reads++;
      try {
        final bytes = await provider.provide(TileIdentity(z, x, y));
        if (bytes.isEmpty) return;
        final tile = VectorTile.fromBytes(bytes: bytes);
        for (final layer in tile.layers) {
          if (layer.name != 'places') continue;
          final extent = layer.extent.toDouble();
          for (final f in layer.features) {
            try {
              final props = f.decodeProperties();
              final name = props['name:es']?.dartStringValue ??
                  props['name']?.dartStringValue;
              if (name == null || name.isEmpty) continue;
              final kind = props['kind']?.dartStringValue ?? 'place';
              // Countries/regions aren't useful "take me there" targets.
              if (kind == 'country') continue;
              final geom = f.decodeGeometry();
              List<num>? pt;
              if (geom is GeometryPoint) {
                pt = geom.coordinates;
              } else if (geom is GeometryMultiPoint) {
                pt = geom.coordinates.isEmpty ? null : geom.coordinates.first;
              }
              if (pt == null) continue;
              final loc = _tilePointToLatLng(
                  x, y, z, pt[0].toDouble(), pt[1].toDouble(), extent);
              final key = '$name@${loc.latitude.toStringAsFixed(2)},'
                  '${loc.longitude.toStringAsFixed(2)}';
              if (seen.add(key)) {
                entries.add(
                    PlaceEntry(name: name, kind: kind, location: loc));
              }
            } catch (_) {}
          }
        }
      } catch (_) {
        // Missing tile — outside the map's coverage.
      }
    }

    // Phase 1: which z4 tiles have data at all?
    final hits = <(int, int)>[];
    for (var x = 0; x < 16; x++) {
      for (var y = 0; y < 16; y++) {
        try {
          final bytes = await provider.provide(TileIdentity(4, x, y));
          if (bytes.isNotEmpty) hits.add((x, y));
        } catch (_) {}
      }
    }
    // Phase 2: read places at z8 inside populated z4 tiles (16x16 children).
    for (final (hx, hy) in hits) {
      for (var dx = 0; dx < 16; dx++) {
        for (var dy = 0; dy < 16; dy++) {
          await scanTile(8, hx * 16 + dx, hy * 16 + dy);
        }
      }
    }

    final index = PlaceIndex._(entries);
    _cache[cacheKey] = index;
    return index;
  }

  /// Ranked matches: prefix beats substring; nearer beats farther.
  List<PlaceEntry> search(String query, {LatLng? near, int limit = 20}) {
    final q = _norm(query);
    if (q.length < 2) return const [];
    final scored = <(PlaceEntry, double)>[];
    for (final e in entries) {
      final n = _norm(e.name);
      double score;
      if (n == q) {
        score = 0;
      } else if (n.startsWith(q)) {
        score = 1;
      } else if (n.contains(q)) {
        score = 2;
      } else {
        continue;
      }
      if (near != null) {
        score += _haversineKm(near, e.location) / 20000; // gentle tiebreak
      }
      scored.add((e, score));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final (e, _) in scored.take(limit)) e];
  }

  static String _norm(String s) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    var out = s.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final la1 = a.latitude * math.pi / 180;
    final la2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  static LatLng _tilePointToLatLng(
      int tx, int ty, int z, double px, double py, double extent) {
    final n = (1 << z).toDouble();
    final worldX = tx + px / extent;
    final worldY = ty + py / extent;
    final lon = worldX / n * 360 - 180;
    final latRad = math.atan(
        (math.exp(math.pi * (1 - 2 * worldY / n)) -
                math.exp(-math.pi * (1 - 2 * worldY / n))) /
            2);
    return LatLng(latRad * 180 / math.pi, lon);
  }
}
