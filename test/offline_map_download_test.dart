import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:prepper_pad/modules/maps/download_from_here.dart';
import 'package:prepper_pad/modules/maps/map_coverage.dart';

void main() {
  test('download-from-here builds a sane bbox around the center', () {
    const center = LatLng(14.0818, -87.2068);
    final bbox = bboxFromCenter(center, 5);
    final parts = bbox.split(',').map(double.parse).toList();

    expect(parts, hasLength(4));
    final minLon = parts[0];
    final minLat = parts[1];
    final maxLon = parts[2];
    final maxLat = parts[3];

    expect(minLat, lessThan(center.latitude));
    expect(maxLat, greaterThan(center.latitude));
    expect(minLon, lessThan(center.longitude));
    expect(maxLon, greaterThan(center.longitude));
    // 5 km radius should span roughly 10 km north/south.
    expect((maxLat - minLat) * 111.0, closeTo(10, 0.2));
  });

  test('region-from-center creates small, valid extraction regions', () {
    const center = LatLng(14.0818, -87.2068);

    final city = regionFromCenter(center, 5);
    final country = regionFromCenter(center, 200);

    expect(city.id, startsWith('aream14d08nm87d21em5km'));
    expect(city.fileName, endsWith('.pmtiles'));
    expect(city.bbox, isNotNull);
    expect(city.maxZoom, 15);
    expect(country.maxZoom, 12);
  });

  test('coverage check prevents re-downloading installed areas', () {
    final coverage = MapCoverage(
      fileName: 'tegucigalpa.pmtiles',
      minLat: 13.9,
      minLon: -87.4,
      maxLat: 14.3,
      maxLon: -87.0,
      minZoom: 0,
      maxZoom: 15,
      centerLat: 14.1,
      centerLon: -87.2,
      centerZoom: 12,
    );

    expect(
        isAlreadyCovered(const LatLng(14.0818, -87.2068), [coverage]), isTrue);
    expect(isAlreadyCovered(const LatLng(15.5, -88.0), [coverage]), isFalse);
    expect(coverage.polygon, hasLength(4));
  });
}
