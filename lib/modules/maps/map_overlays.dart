// User-created map overlays persisted as GeoJSON in the portable library
// (~/PrepperPad/maps/overlays.geojson). Covers custom POIs (shelter, water,
// meeting point, resources) and tactical layers (safe zones, risk zones,
// evacuation routes). Being GeoJSON, overlays travel with the library and
// can be shared or edited by hand.
import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../../core/prepper_library.dart';

/// What an overlay represents. Drives icon, color and geometry kind.
enum OverlayKind {
  // Custom points
  shelter,
  water,
  meetingPoint,
  resource,
  customPoint,
  barrier, // gate/portón — routing cuts edges near it
  // Tactical areas / lines
  safeZone, // polygon
  riskZone, // polygon (has dangerLevel)
  evacuationRoute, // polyline
}

extension OverlayKindInfo on OverlayKind {
  bool get isArea =>
      this == OverlayKind.safeZone || this == OverlayKind.riskZone;
  bool get isLine => this == OverlayKind.evacuationRoute;
  bool get isPoint => !isArea && !isLine;

  String get label {
    switch (this) {
      case OverlayKind.shelter:
        return 'Refugio';
      case OverlayKind.water:
        return 'Agua';
      case OverlayKind.meetingPoint:
        return 'Punto de reunión';
      case OverlayKind.resource:
        return 'Recurso';
      case OverlayKind.customPoint:
        return 'Punto';
      case OverlayKind.barrier:
        return 'Portón/Barrera';
      case OverlayKind.safeZone:
        return 'Zona segura';
      case OverlayKind.riskZone:
        return 'Zona de riesgo';
      case OverlayKind.evacuationRoute:
        return 'Ruta de evacuación';
    }
  }
}

class MapOverlay {
  MapOverlay({
    required this.id,
    required this.kind,
    required this.points,
    this.name,
    this.note,
    this.dangerLevel,
  });

  final String id;
  final OverlayKind kind;
  final List<LatLng> points; // 1 for point, N for line/polygon
  String? name;
  String? note;
  int? dangerLevel; // 1..5 for riskZone

  LatLng get anchor => points.first;

  Map<String, dynamic> toFeature() {
    final coords = points.map((p) => [p.longitude, p.latitude]).toList();
    final Map<String, dynamic> geometry;
    if (kind.isPoint) {
      geometry = {'type': 'Point', 'coordinates': coords.first};
    } else if (kind.isLine) {
      geometry = {'type': 'LineString', 'coordinates': coords};
    } else {
      // Polygon: GeoJSON wants a closed ring.
      final ring = [...coords, coords.first];
      geometry = {
        'type': 'Polygon',
        'coordinates': [ring],
      };
    }
    return {
      'type': 'Feature',
      'geometry': geometry,
      'properties': {
        'id': id,
        'kind': kind.name,
        if (name != null) 'name': name,
        if (note != null) 'note': note,
        if (dangerLevel != null) 'dangerLevel': dangerLevel,
      },
    };
  }

  static MapOverlay? fromFeature(Map<String, dynamic> f) {
    try {
      final props = (f['properties'] as Map).cast<String, dynamic>();
      final kind = OverlayKind.values.firstWhere(
        (k) => k.name == props['kind'],
        orElse: () => OverlayKind.customPoint,
      );
      final geom = (f['geometry'] as Map).cast<String, dynamic>();
      final type = geom['type'];
      final rawCoords = geom['coordinates'] as List;
      List<LatLng> pts;
      if (type == 'Point') {
        pts = [
          LatLng((rawCoords[1] as num).toDouble(),
              (rawCoords[0] as num).toDouble())
        ];
      } else if (type == 'LineString') {
        pts = rawCoords
            .map((c) =>
                LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
      } else {
        // Polygon: take outer ring, drop the closing duplicate.
        final ring = (rawCoords.first as List);
        pts = ring
            .map((c) =>
                LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
        if (pts.length > 1 && pts.first == pts.last) pts.removeLast();
      }
      return MapOverlay(
        id: props['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        kind: kind,
        points: pts,
        name: props['name']?.toString(),
        note: props['note']?.toString(),
        dangerLevel: (props['dangerLevel'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Loads/saves overlays as a GeoJSON FeatureCollection.
class OverlayStore {
  OverlayStore._();
  static final OverlayStore instance = OverlayStore._();

  final List<MapOverlay> overlays = [];
  bool _loaded = false;

  File get _file =>
      File('${PrepperLibrary.instance.mapsDir.path}/overlays.geojson');

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      if (!_file.existsSync()) return;
      final data = jsonDecode(await _file.readAsString());
      final features = (data['features'] as List?) ?? [];
      for (final f in features) {
        final o = MapOverlay.fromFeature((f as Map).cast<String, dynamic>());
        if (o != null) overlays.add(o);
      }
    } catch (_) {
      // Corrupt file — start empty rather than crash.
    }
  }

  Future<void> _save() async {
    final fc = {
      'type': 'FeatureCollection',
      'features': overlays.map((o) => o.toFeature()).toList(),
    };
    // Atomic write: write to temp file then rename, so a crash mid-write
    // never corrupts the existing overlays file.
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(fc));
    await tmp.rename(_file.path);
  }

  Future<void> add(MapOverlay o) async {
    overlays.add(o);
    await _save();
  }

  Future<void> remove(String id) async {
    overlays.removeWhere((o) => o.id == id);
    await _save();
  }

  Future<void> update(MapOverlay o) async {
    final i = overlays.indexWhere((e) => e.id == o.id);
    if (i >= 0) overlays[i] = o;
    await _save();
  }
}
