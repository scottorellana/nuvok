// Reads coverage metadata (bbox + zoom range) from installed .pmtiles files
// so the map can draw subtle "downloaded area" outlines — just like Google
// Maps shows your offline regions with a blue tint.
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

/// Geographic coverage of a single .pmtiles file.
class MapCoverage {
  MapCoverage({
    required this.fileName,
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
    required this.minZoom,
    required this.maxZoom,
    required this.centerLat,
    required this.centerLon,
    required this.centerZoom,
  });

  final String fileName;
  final double minLat, minLon, maxLat, maxLon;
  final int minZoom, maxZoom;
  final double centerLat, centerLon;
  final int centerZoom;

  /// Four corners of the bounding box, as a polygon for flutter_map.
  List<LatLng> get polygon => [
        LatLng(maxLat, minLon), // NW
        LatLng(maxLat, maxLon), // NE
        LatLng(minLat, maxLon), // SE
        LatLng(minLat, minLon), // SW
      ];

  LatLng get center => LatLng(centerLat, centerLon);

  String get displayName {
    final base = fileName.replaceAll('.pmtiles', '');
    return base;
  }

  @override
  String toString() =>
      '$displayName [${minLat.toStringAsFixed(2)},${minLon.toStringAsFixed(2)} → '
      '${maxLat.toStringAsFixed(2)},${maxLon.toStringAsFixed(2)}]';
}

class MapCoverageReader {
  /// Builds coverage metadata from an already-opened provider. Used by the
  /// maps screen so loading N regions does not open each PMTiles archive twice.
  static MapCoverage fromProvider(
      File mapFile, PmTilesVectorTileProvider provider) {
    final header = provider.archive.header;
    return MapCoverage(
      fileName: mapFile.uri.pathSegments.last,
      minLat: header.minPosition.latitude,
      minLon: header.minPosition.longitude,
      maxLat: header.maxPosition.latitude,
      maxLon: header.maxPosition.longitude,
      minZoom: header.minZoom,
      maxZoom: header.maxZoom,
      centerLat: header.centerPosition.latitude,
      centerLon: header.centerPosition.longitude,
      centerZoom: header.centerZoom,
    );
  }

  /// Reads coverage from a .pmtiles file. Returns null on any error (corrupt
  /// or partial file) — callers should skip nulls silently.
  static Future<MapCoverage?> read(File mapFile) async {
    try {
      final provider = await PmTilesVectorTileProvider.fromSource(mapFile.path);
      return fromProvider(mapFile, provider);
    } catch (_) {
      return null;
    }
  }

  /// Reads coverage for all .pmtiles files in [maps], skipping errors.
  static Future<List<MapCoverage>> readAll(List<File> maps) async {
    final results = <MapCoverage>[];
    for (final f in maps) {
      final cov = await read(f);
      if (cov != null) results.add(cov);
    }
    return results;
  }
}
