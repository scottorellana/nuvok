import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nuvok/modules/maps/download_from_here.dart';
import 'package:nuvok/modules/maps/map_coverage.dart';

void main() {
  test('bboxFromCenter creates symmetric bbox around center', () {
    final bbox = bboxFromCenter(const LatLng(0, 0), 111);
    final parts = bbox.split(',').map(double.parse).toList();

    expect(parts.length, 4);
    expect(parts[0], closeTo(-1, 0.01)); // min lon
    expect(parts[1], closeTo(-1, 0.01)); // min lat
    expect(parts[2], closeTo(1, 0.01)); // max lon
    expect(parts[3], closeTo(1, 0.01)); // max lat
  });

  test('regionFromCenter chooses lower maxZoom for large areas', () {
    final small = regionFromCenter(const LatLng(15.5, -88.0), 5);
    final medium = regionFromCenter(const LatLng(15.5, -88.0), 50);
    final large = regionFromCenter(const LatLng(15.5, -88.0), 200);

    expect(small.bbox, isNotNull);
    expect(small.maxZoom, 15);
    expect(medium.maxZoom, 14);
    expect(large.maxZoom, 12);
    expect(small.id,
        contains('area')); // contains "area" despite dash → m conversion
  });

  test('isAlreadyCovered returns true only when point is inside coverage', () {
    final coverage = MapCoverage(
      fileName: 'honduras.pmtiles',
      minLat: 12.0,
      minLon: -90.0,
      maxLat: 18.0,
      maxLon: -83.0,
      minZoom: 0,
      maxZoom: 15,
      centerLat: 15.0,
      centerLon: -86.0,
      centerZoom: 7,
    );

    expect(isAlreadyCovered(const LatLng(15.5, -88.0), [coverage]), isTrue);
    expect(isAlreadyCovered(const LatLng(20.0, -88.0), [coverage]), isFalse);
    expect(isAlreadyCovered(const LatLng(15.5, -80.0), [coverage]), isFalse);
  });
}
