// Offline street routing over the road network already inside the user's
// .pmtiles. We decode the `roads` layer for the tiles between origin and
// destination, build a graph (nodes = shared coordinates, edges = segments
// weighted by real distance), snap the endpoints to the nearest road, and
// run A*. No routing server, no extra downloads — it works anywhere the user
// has a map. Quality is limited by the road detail in the tiles (good in
// cities); it is not turn-by-turn voice navigation.
//
// Access rules: Protomaps tiles carry `access` (private/no), `oneway` and
// `kind_detail`, so routes avoid private streets and one-way violations like
// mainstream navigators do. Gates aren't in the basemap, so user-marked
// barrier points cut nearby edges, and user risk zones penalize crossing.
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile/vector_tile.dart';

enum RouteProfile { vehicle, walk }

/// User-defined obstacles the route must respect: barrier points (gates)
/// cut nearby edges; risk-zone polygons multiply edge cost so the route
/// goes around them unless there is no alternative.
class RouteRestrictions {
  const RouteRestrictions(
      {this.barriers = const [], this.riskZones = const []});
  final List<LatLng> barriers;
  final List<List<LatLng>> riskZones;

  bool get isEmpty => barriers.isEmpty && riskZones.isEmpty;
}

/// Road attributes read from the tile that drive the per-profile rules.
class EdgeAttrs {
  const EdgeAttrs({this.kindDetail, this.access, this.oneway = false});
  final String? kindDetail;
  final String? access;
  final bool oneway;
}

class RouteResult {
  RouteResult({
    required this.path,
    required this.distanceMeters,
    this.restricted = true,
  });
  final List<LatLng> path;
  final double distanceMeters;

  /// False when the route came from the unrestricted fallback and may cross
  /// private streets, barriers or risk zones.
  final bool restricted;
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

  // Private streets are allowed only this close to the origin/destination:
  // you can leave your own gated community and enter the destination's, but
  // never cut through a third one.
  static const double _privateGraceMeters = 400;

  // A user-marked gate/barrier cuts any edge passing within this distance.
  static const double _barrierCutMeters = 15;

  // Crossing a user risk zone costs this many times the real distance.
  static const double _riskZoneMultiplier = 10;

  /// Cost multiplier for an edge under [profile], or null if the edge must
  /// not be used at all. Private access is handled separately (grace radius).
  static double? edgeMultiplier(EdgeAttrs a, RouteProfile profile) {
    final access = a.access;
    if (access == 'private' || access == 'no') return null;
    final kd = a.kindDetail;
    if (profile == RouteProfile.vehicle) {
      const forbidden = {
        'footway',
        'steps',
        'path',
        'pedestrian',
        'sidewalk',
        'crossing',
        'cycleway',
      };
      if (forbidden.contains(kd)) return null;
      if (kd == 'track') return 3.0;
    }
    return 1.0;
  }

  /// Whether the reverse direction of a one-way road is forbidden.
  static bool onewayBlocksReverse(EdgeAttrs a, RouteProfile profile) =>
      profile == RouteProfile.vehicle && a.oneway;

  /// True if segment a-b passes within [_barrierCutMeters] of any barrier
  /// (checked at both endpoints and the midpoint — segments are short).
  static bool nearAnyBarrier(LatLng a, LatLng b, List<LatLng> barriers) {
    if (barriers.isEmpty) return false;
    final mid =
        LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
    for (final barrier in barriers) {
      if (_haversine(a, barrier) < _barrierCutMeters ||
          _haversine(b, barrier) < _barrierCutMeters ||
          _haversine(mid, barrier) < _barrierCutMeters) {
        return true;
      }
    }
    return false;
  }

  /// Ray-casting point-in-polygon over every risk zone.
  static bool insideAnyZone(LatLng p, List<List<LatLng>> zones) {
    for (final zone in zones) {
      if (zone.length < 3) continue;
      var inside = false;
      for (var i = 0, j = zone.length - 1; i < zone.length; j = i++) {
        final yi = zone[i].latitude, xi = zone[i].longitude;
        final yj = zone[j].latitude, xj = zone[j].longitude;
        final intersects = ((yi > p.latitude) != (yj > p.latitude)) &&
            (p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi);
        if (intersects) inside = !inside;
      }
      if (inside) return true;
    }
    return false;
  }

  /// Computes a street-following route from [origin] to [destination] using
  /// the roads in [provider]. Applies [profile] rules and [restrictions];
  /// if no compliant route exists, retries unrestricted and marks the result
  /// with `restricted: false` so the UI can warn.
  static Future<RouteOutcome> route({
    required VectorTileProvider provider,
    required LatLng origin,
    required LatLng destination,
    int zoom = 14,
    int maxTiles = 80,
    RouteProfile profile = RouteProfile.vehicle,
    RouteRestrictions restrictions = const RouteRestrictions(),
    bool ignoreRestrictions = false,
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
              final attrs = _attrsOf(f);
              double? mult;
              if (ignoreRestrictions) {
                mult = 1.0;
              } else {
                if (attrs.access == 'private' || attrs.access == 'no') {
                  // Grace: private streets are usable only near the ends of
                  // the trip (your own colonia / the destination's).
                  mult = null; // decided per-segment below
                } else {
                  mult = edgeMultiplier(attrs, profile);
                  if (mult == null) continue; // forbidden kind for profile
                }
              }
              final directed =
                  !ignoreRestrictions && onewayBlocksReverse(attrs, profile);
              final lines = _lineStrings(f);
              for (final line in lines) {
                final pts = line
                    .map((c) => _tilePointToLatLng(
                        tx, ty, z, c[0].toDouble(), c[1].toDouble(), extent))
                    .toList();
                for (var i = 0; i + 1 < pts.length; i++) {
                  final a = pts[i], b = pts[i + 1];
                  var m = mult;
                  if (m == null) {
                    // Private/no access: allowed only within the grace
                    // radius of origin or destination.
                    final nearEnds =
                        _haversine(a, origin) < _privateGraceMeters ||
                            _haversine(a, destination) < _privateGraceMeters ||
                            _haversine(b, origin) < _privateGraceMeters ||
                            _haversine(b, destination) < _privateGraceMeters;
                    if (!nearEnds) continue;
                    m = 1.0;
                  }
                  if (!ignoreRestrictions &&
                      nearAnyBarrier(a, b, restrictions.barriers)) {
                    continue; // a marked gate cuts this edge
                  }
                  if (!ignoreRestrictions &&
                      restrictions.riskZones.isNotEmpty) {
                    final mid = LatLng((a.latitude + b.latitude) / 2,
                        (a.longitude + b.longitude) / 2);
                    if (insideAnyZone(mid, restrictions.riskZones)) {
                      m *= _riskZoneMultiplier;
                    }
                  }
                  _addEdge(graph, nodePos, a, b, m, bidirectional: !directed);
                }
              }
            }
          }
        } catch (_) {
          // Missing tile — skip.
        }
      }
    }

    if (nodePos.isEmpty) {
      return _fallbackOrStatus(RouteStatus.noRoadsNearby,
          provider: provider,
          origin: origin,
          destination: destination,
          zoom: zoom,
          maxTiles: maxTiles,
          profile: profile,
          restrictions: restrictions,
          alreadyUnrestricted: ignoreRestrictions);
    }

    // Protomaps road tiles are drawn, not noded for routing: roads that cross
    // at an intersection often don't share a vertex, and segments are clipped
    // at tile edges. Stitch the graph by connecting any two nodes within a
    // few metres, which reconnects intersections and tile boundaries.
    // Stitch links also respect marked barriers so a gate can't be bridged.
    _stitch(graph, nodePos,
        barriers: ignoreRestrictions ? const [] : restrictions.barriers);

    // Connect synthetic start/goal nodes to the K nearest road nodes, so the
    // search can enter the network from several points — robust against the
    // closest node being a disconnected spur or a dead-end.
    const start = '__start__';
    const goal = '__goal__';
    nodePos[start] = origin;
    nodePos[goal] = destination;
    final nearStart = _kNearest(nodePos, origin, 8, exclude: {start, goal});
    final nearGoal = _kNearest(nodePos, destination, 8, exclude: {start, goal});
    if (nearStart.isEmpty || nearGoal.isEmpty) {
      return _fallbackOrStatus(RouteStatus.noRoadsNearby,
          provider: provider,
          origin: origin,
          destination: destination,
          zoom: zoom,
          maxTiles: maxTiles,
          profile: profile,
          restrictions: restrictions,
          alreadyUnrestricted: ignoreRestrictions);
    }
    for (final k in nearStart) {
      graph
          .putIfAbsent(start, () => [])
          .add(_Edge(k, _haversine(origin, nodePos[k]!)));
    }
    for (final k in nearGoal) {
      graph
          .putIfAbsent(k, () => [])
          .add(_Edge(goal, _haversine(nodePos[k]!, destination)));
    }

    final path = _aStar(graph, nodePos, start, goal, destination);
    if (path == null) {
      return _fallbackOrStatus(RouteStatus.noPath,
          provider: provider,
          origin: origin,
          destination: destination,
          zoom: zoom,
          maxTiles: maxTiles,
          profile: profile,
          restrictions: restrictions,
          alreadyUnrestricted: ignoreRestrictions);
    }

    // The path already begins at the exact origin and ends at the exact
    // destination (synthetic nodes), connecting them to the road network.
    final full = <LatLng>[...path.map((k) => nodePos[k]!)];
    var dist = 0.0;
    for (var i = 0; i + 1 < full.length; i++) {
      dist += _haversine(full[i], full[i + 1]);
    }
    return RouteOutcome(
        RouteStatus.ok,
        RouteResult(
            path: full, distanceMeters: dist, restricted: !ignoreRestrictions));
  }

  /// When a restricted search fails, retry once without restrictions so an
  /// emergency user still gets *a* route (marked `restricted:false`).
  static Future<RouteOutcome> _fallbackOrStatus(
    RouteStatus status, {
    required VectorTileProvider provider,
    required LatLng origin,
    required LatLng destination,
    required int zoom,
    required int maxTiles,
    required RouteProfile profile,
    required RouteRestrictions restrictions,
    required bool alreadyUnrestricted,
  }) async {
    // Nothing to relax, or we already relaxed: report the failure as-is.
    if (alreadyUnrestricted) return RouteOutcome(status);
    return route(
      provider: provider,
      origin: origin,
      destination: destination,
      zoom: zoom,
      maxTiles: maxTiles,
      profile: profile,
      restrictions: restrictions,
      ignoreRestrictions: true,
    );
  }

  /// Reads the routing-relevant properties of a road feature.
  static EdgeAttrs _attrsOf(VectorTileFeature f) {
    try {
      final props = f.decodeProperties();
      final kd = props['kind_detail']?.dartStringValue ??
          props['kind']?.dartStringValue;
      final access = props['access']?.dartStringValue;
      final ow = props['oneway'];
      final owStr = ow?.dartStringValue;
      final owInt = ow?.dartIntValue?.toInt();
      final owBool = ow?.dartBoolValue;
      final oneway = owBool == true ||
          owInt == 1 ||
          owStr == 'yes' ||
          owStr == '1' ||
          owStr == 'true';
      return EdgeAttrs(kindDetail: kd, access: access, oneway: oneway);
    } catch (_) {
      return const EdgeAttrs();
    }
  }

  // Nodes closer than this are treated as the same junction and linked.
  static const double _stitchMeters = 20;

  /// Connects graph nodes that are within [_stitchMeters] of each other using
  /// a spatial hash grid, so crossing roads and tile-boundary fragments join
  /// into a routable network. Links near a marked barrier are not created —
  /// otherwise the stitch would bridge right across a gate.
  static void _stitch(
      Map<String, List<_Edge>> graph, Map<String, LatLng> nodePos,
      {List<LatLng> barriers = const []}) {
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
            final q = nodePos[other]!;
            final d = _haversine(p, q);
            if (d <= _stitchMeters && !nearAnyBarrier(p, q, barriers)) {
              graph.putIfAbsent(k, () => []).add(_Edge(other, d));
            }
          }
        }
      }
    }
  }

  static void _addEdge(Map<String, List<_Edge>> graph,
      Map<String, LatLng> nodePos, LatLng a, LatLng b, double multiplier,
      {bool bidirectional = true}) {
    final ka = _key(a);
    final kb = _key(b);
    if (ka == kb) return;
    nodePos.putIfAbsent(ka, () => a);
    nodePos.putIfAbsent(kb, () => b);
    final w = _haversine(a, b) * multiplier;
    graph.putIfAbsent(ka, () => []).add(_Edge(kb, w));
    if (bidirectional) {
      graph.putIfAbsent(kb, () => []).add(_Edge(ka, w));
    }
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
  static List<String> _kNearest(Map<String, LatLng> nodePos, LatLng p, int k,
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
    final latRad = math.atan((math.exp(math.pi * (1 - 2 * worldY / n)) -
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
