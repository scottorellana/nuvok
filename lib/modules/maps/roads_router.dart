// Offline street routing over the road network already inside the user's
// .pmtiles. We decode the `roads` layer for the tiles between origin and
// destination, build a graph (nodes = shared coordinates, edges = segments
// weighted by real distance), snap the endpoints to the nearest road, and
// run A*. No routing server, no extra downloads — it works anywhere the user
// has a map. Quality is limited by the road detail in the tiles (good in
// cities); it is not turn-by-turn voice navigation.
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile/vector_tile.dart';

class RouteResult {
  RouteResult({required this.path, required this.distanceMeters});
  final List<LatLng> path;
  final double distanceMeters;
}

enum RouteStatus { ok, noRoadsNearby, noPath, tooFar }

class RouteOutcome {
  RouteOutcome(this.status, [this.result]);
  final RouteStatus status;
  final RouteResult? result;

  String get message {
    switch (status) {
      case RouteStatus.noRoadsNearby:
        return 'No hay calles cerca del origen o el destino en este mapa.';
      case RouteStatus.noPath:
        return 'No se encontró una ruta por calles entre los dos puntos.';
      case RouteStatus.tooFar:
        return 'Los puntos están muy lejos para calcular la ruta con este '
            'mapa. Acércalos o usa una región con más detalle.';
      case RouteStatus.ok:
        return '';
    }
  }
}

class RoadRouter {
  // Snap coordinates to ~1.1 m so segment endpoints shared between adjacent
  // tiles merge into the same graph node.
  static const int _coordDecimals = 5;

  /// Computes a street-following route from [origin] to [destination] using
  /// the roads in [provider]. [zoom] should be the current map zoom; routing
  /// reads tiles at a road-rich zoom (>=14).
  static Future<RouteOutcome> route({
    required VectorTileProvider provider,
    required LatLng origin,
    required LatLng destination,
    int zoom = 14,
    int maxTiles = 80,
  }) async {
    final z = zoom.clamp(13, provider.maximumZoom);

    // Bounding box covering both points, padded a little so the connecting
    // roads near the edges are included.
    final south = math.min(origin.latitude, destination.latitude);
    final north = math.max(origin.latitude, destination.latitude);
    final west = math.min(origin.longitude, destination.longitude);
    final east = math.max(origin.longitude, destination.longitude);
    final padLat = math.max(0.01, (north - south) * 0.2);
    final padLon = math.max(0.01, (east - west) * 0.2);
    final bounds = LatLngBounds(
      LatLng(south - padLat, west - padLon),
      LatLng(north + padLat, east + padLon),
    );

    final (minX, maxY) = _tileXY(bounds.south, bounds.west, z);
    final (maxX, minY) = _tileXY(bounds.north, bounds.east, z);
    if ((maxX - minX + 1) * (maxY - minY + 1) > maxTiles) {
      return RouteOutcome(RouteStatus.tooFar);
    }

    // Build the graph from all road segments in the covered tiles.
    final graph = <String, List<_Edge>>{};
    final nodePos = <String, LatLng>{};
    var tilesRead = 0;
    for (var tx = minX; tx <= maxX; tx++) {
      for (var ty = minY; ty <= maxY; ty++) {
        if (tilesRead >= maxTiles) break;
        tilesRead++;
        try {
          final bytes = await provider.provide(TileIdentity(z, tx, ty));
          if (bytes.isEmpty) continue;
          final tile = VectorTile.fromBytes(bytes: bytes);
          for (final layer in tile.layers) {
            if (layer.name != 'roads') continue;
            final extent = layer.extent.toDouble();
            for (final f in layer.features) {
              final lines = _lineStrings(f);
              for (final line in lines) {
                final pts = line
                    .map((c) => _tilePointToLatLng(
                        tx, ty, z, c[0].toDouble(), c[1].toDouble(), extent))
                    .toList();
                for (var i = 0; i + 1 < pts.length; i++) {
                  _addEdge(graph, nodePos, pts[i], pts[i + 1]);
                }
              }
            }
          }
        } catch (_) {
          // Missing tile — skip.
        }
      }
    }

    if (nodePos.isEmpty) return RouteOutcome(RouteStatus.noRoadsNearby);

    // Protomaps road tiles are drawn, not noded for routing: roads that cross
    // at an intersection often don't share a vertex, and segments are clipped
    // at tile edges. Stitch the graph by connecting any two nodes within a
    // few metres, which reconnects intersections and tile boundaries.
    _stitch(graph, nodePos);

    // Connect synthetic start/goal nodes to the K nearest road nodes, so the
    // search can enter the network from several points — robust against the
    // closest node being a disconnected stub or a dead-end.
    const start = '__start__';
    const goal = '__goal__';
    nodePos[start] = origin;
    nodePos[goal] = destination;
    final nearStart = _kNearest(nodePos, origin, 8, exclude: {start, goal});
    final nearGoal = _kNearest(nodePos, destination, 8, exclude: {start, goal});
    if (nearStart.isEmpty || nearGoal.isEmpty) {
      return RouteOutcome(RouteStatus.noRoadsNearby);
    }
    for (final k in nearStart) {
      graph.putIfAbsent(start, () => []).add(_Edge(k, _haversine(origin, nodePos[k]!)));
    }
    for (final k in nearGoal) {
      graph.putIfAbsent(k, () => []).add(_Edge(goal, _haversine(nodePos[k]!, destination)));
    }

    final path = _aStar(graph, nodePos, start, goal, destination);
    if (path == null) return RouteOutcome(RouteStatus.noPath);

    // The path already begins at the exact origin and ends at the exact
    // destination (synthetic nodes), connecting them to the road network.
    final full = <LatLng>[...path.map((k) => nodePos[k]!)];
    var dist = 0.0;
    for (var i = 0; i + 1 < full.length; i++) {
      dist += _haversine(full[i], full[i + 1]);
    }
    return RouteOutcome(
        RouteStatus.ok, RouteResult(path: full, distanceMeters: dist));
  }

  // Nodes closer than this are treated as the same junction and linked.
  static const double _stitchMeters = 20;

  /// Connects graph nodes that are within [_stitchMeters] of each other using
  /// a spatial hash grid, so crossing roads and tile-boundary fragments join
  /// into a routable network.
  static void _stitch(
      Map<String, List<_Edge>> graph, Map<String, LatLng> nodePos) {
    // Grid cell ~ stitch distance. 0.0002° ≈ 22 m in latitude.
    const cell = 0.0002;
    final buckets = <String, List<String>>{};
    String cellKey(LatLng p) =>
        '${(p.latitude / cell).floor()}:${(p.longitude / cell).floor()}';
    for (final e in nodePos.entries) {
      buckets.putIfAbsent(cellKey(e.value), () => []).add(e.key);
    }
    final keys = nodePos.keys.toList();
    for (final k in keys) {
      final p = nodePos[k]!;
      final ci = (p.latitude / cell).floor();
      final cj = (p.longitude / cell).floor();
      for (var di = -1; di <= 1; di++) {
        for (var dj = -1; dj <= 1; dj++) {
          for (final other in buckets['${ci + di}:${cj + dj}'] ?? const []) {
            if (other == k) continue;
            final d = _haversine(p, nodePos[other]!);
            if (d <= _stitchMeters) {
              graph.putIfAbsent(k, () => []).add(_Edge(other, d));
            }
          }
        }
      }
    }
  }

  static void _addEdge(Map<String, List<_Edge>> graph,
      Map<String, LatLng> nodePos, LatLng a, LatLng b) {
    final ka = _key(a);
    final kb = _key(b);
    if (ka == kb) return;
    nodePos.putIfAbsent(ka, () => a);
    nodePos.putIfAbsent(kb, () => b);
    final w = _haversine(a, b);
    graph.putIfAbsent(ka, () => []).add(_Edge(kb, w));
    graph.putIfAbsent(kb, () => []).add(_Edge(ka, w)); // roads are two-way
  }

  static List<String>? _aStar(
    Map<String, List<_Edge>> graph,
    Map<String, LatLng> nodePos,
    String start,
    String goal,
    LatLng goalPos,
  ) {
    final gScore = <String, double>{start: 0};
    final cameFrom = <String, String>{};
    final open = HeapPriorityQueue<_QNode>((a, b) => a.f.compareTo(b.f));
    open.add(_QNode(start, _haversine(nodePos[start]!, goalPos)));
    final closed = <String>{};

    while (open.isNotEmpty) {
      final current = open.removeFirst();
      if (current.key == goal) return _reconstruct(cameFrom, goal);
      if (!closed.add(current.key)) continue;
      for (final edge in graph[current.key] ?? const <_Edge>[]) {
        if (closed.contains(edge.to)) continue;
        final tentative = gScore[current.key]! + edge.weight;
        if (tentative < (gScore[edge.to] ?? double.infinity)) {
          gScore[edge.to] = tentative;
          cameFrom[edge.to] = current.key;
          final f = tentative + _haversine(nodePos[edge.to]!, goalPos);
          open.add(_QNode(edge.to, f));
        }
      }
    }
    return null;
  }

  static List<String> _reconstruct(Map<String, String> cameFrom, String goal) {
    final path = <String>[goal];
    var cur = goal;
    while (cameFrom.containsKey(cur)) {
      cur = cameFrom[cur]!;
      path.add(cur);
    }
    return path.reversed.toList();
  }

  /// The [k] graph nodes closest to [p] (within a sane radius), used to wire
  /// synthetic start/goal nodes into the network from several entry points.
  static List<String> _kNearest(
      Map<String, LatLng> nodePos, LatLng p, int k,
      {required Set<String> exclude}) {
    final scored = <MapEntry<String, double>>[];
    for (final e in nodePos.entries) {
      if (exclude.contains(e.key)) continue;
      scored.add(MapEntry(e.key, _haversine(e.value, p)));
    }
    scored.sort((a, b) => a.value.compareTo(b.value));
    // Keep the closest few, but drop any absurdly far (> 2 km) — that would
    // mean there is no road near this point.
    return scored
        .take(k)
        .where((e) => e.value < 2000)
        .map((e) => e.key)
        .toList();
  }

  /// Extracts line/multiline coordinate lists (tile-extent space) from a
  /// feature.
  static List<List<List<num>>> _lineStrings(VectorTileFeature f) {
    try {
      final geom = f.decodeGeometry();
      if (geom is GeometryLineString) {
        return [geom.coordinates];
      }
      if (geom is GeometryMultiLineString) {
        return geom.coordinates;
      }
    } catch (_) {}
    return const [];
  }

  static String _key(LatLng p) =>
      '${p.latitude.toStringAsFixed(_coordDecimals)},'
      '${p.longitude.toStringAsFixed(_coordDecimals)}';

  static (int, int) _tileXY(double lat, double lon, int z) {
    final n = 1 << z;
    final x = ((lon + 180) / 360 * n).floor().clamp(0, n - 1);
    final latRad = lat * math.pi / 180;
    final y = ((1 -
                math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
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
    final latRad =
        math.atan((math.exp(math.pi * (1 - 2 * worldY / n)) -
                math.exp(-math.pi * (1 - 2 * worldY / n))) /
            2);
    return LatLng(latRad * 180 / math.pi, lon);
  }

  static double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final la1 = a.latitude * math.pi / 180;
    final la2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }
}

class _Edge {
  _Edge(this.to, this.weight);
  final String to;
  final double weight;
}

class _QNode {
  _QNode(this.key, this.f);
  final String key;
  final double f;
}
