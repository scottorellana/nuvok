// "Download from here": takes the visible map area (or a radius around the
// device) and extracts it from the Protomaps daily build — so the user can
// grab any area of the world, like Google Maps' offline download flow.
//
// Desktop-only (needs the pmtiles CLI); on mobile the user is directed to
// the Depot → "Por URL" or "Importar" alternatives.
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../depot/map_catalog.dart';
import 'map_coverage.dart';

/// Radius options presented to the user (km).
const kDownloadRadiusOptions = <(String, double)>[
  ('Ciudad (5 km)', 5),
  ('Urbano (15 km)', 15),
  ('Región (50 km)', 50),
  ('País pequeño (200 km)', 200),
];

/// Computes a bounding box from a center point and a radius in km.
String bboxFromCenter(LatLng center, double radiusKm) {
  // 1 degree latitude ≈ 111.0 km
  final dLat = radiusKm / 111.0;
  // 1 degree longitude shrinks with cos(latitude)
  final dLon = radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180));

  final minLon = center.longitude - dLon;
  final maxLon = center.longitude + dLon;
  final minLat = center.latitude - dLat;
  final maxLat = center.latitude + dLat;
  return '${minLon.toStringAsFixed(4)},'
      '${minLat.toStringAsFixed(4)},'
      '${maxLon.toStringAsFixed(4)},'
      '${maxLat.toStringAsFixed(4)}';
}

/// Creates a MapRegion ready for extraction from a center point + radius.
/// The region name is derived from the coordinates to be unique.
MapRegion regionFromCenter(LatLng center, double radiusKm) {
  final bbox = bboxFromCenter(center, radiusKm);
  final radiusLabel = radiusKm < 10
      ? '${radiusKm.toStringAsFixed(0)}km'
      : '${radiusKm.toStringAsFixed(0)}km';
  final latLabel = center.latitude.toStringAsFixed(2).replaceAll('.', 'd');
  final lonLabel = center.longitude.toStringAsFixed(2).replaceAll('.', 'd');
  final id = 'area-${latLabel}n${lonLabel}e-$radiusLabel'.replaceAll('-', 'm');
  final name = 'Área ${center.latitude.toStringAsFixed(2)}, '
      '${center.longitude.toStringAsFixed(2)} ($radiusLabel)';
  return MapRegion(
    id: id,
    name: name,
    flag: '📍',
    group: 'Descargadas',
    sizeMB: 0,
    bbox: bbox,
    // Cap zoom for larger areas so they don't get too big.
    maxZoom: radiusKm <= 15 ? 15 : (radiusKm <= 50 ? 14 : 12),
  );
}

/// Checks whether [point] is already covered by any of the installed regions.
/// Avoids re-downloading an area the user already has.
bool isAlreadyCovered(LatLng point, List<MapCoverage> coverages) {
  for (final c in coverages) {
    if (point.latitude >= c.minLat &&
        point.latitude <= c.maxLat &&
        point.longitude >= c.minLon &&
        point.longitude <= c.maxLon) {
      return true;
    }
  }
  return false;
}
