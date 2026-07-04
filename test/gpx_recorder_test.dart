import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/maps/gpx_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrackPoint', () {
    test('toGpx genera XML válido con ele y time', () {
      final tp = TrackPoint(
        lat: 15.5041,
        lon: -88.0250,
        elevation: 120.5,
        time: DateTime.parse('2025-01-15T10:30:00'),
      );
      final xml = tp.toGpx();
      expect(xml, contains('lat="15.5041"'));
      expect(xml, contains('lon="-88.025"'));
      expect(xml, contains('<ele>120.5</ele>'));
      expect(xml, contains('<time>'));
    });

    test('toGpx sin elevación omite tag ele', () {
      final tp = TrackPoint(
        lat: 15.5,
        lon: -88.0,
        time: DateTime.now(),
      );
      final xml = tp.toGpx();
      expect(xml, isNot(contains('<ele>')));
    });
  });

  group('GpxTrack', () {
    test('toGpx genera documento GPX 1.1 válido', () {
      final track = GpxTrack(
        name: 'Test Track',
        startTime: DateTime.parse('2025-01-15T10:00:00'),
        points: [
          TrackPoint(
              lat: 15.5,
              lon: -88.0,
              time: DateTime.parse('2025-01-15T10:00:00')),
          TrackPoint(
              lat: 15.51,
              lon: -88.01,
              time: DateTime.parse('2025-01-15T10:05:00')),
        ],
      );
      final gpx = track.toGpx();
      expect(gpx, contains('<?xml version="1.0"'));
      expect(gpx, contains('xmlns="http://www.topografix.com/GPX/1/1"'));
      expect(gpx, contains('<name>Test Track</name>'));
      expect(gpx, contains('<trkseg>'));
      expect(gpx, contains('lat="15.5"'));
    });

    test('distanceMeters calcula distancia acumulada', () {
      final track = GpxTrack(
        name: 'Test',
        startTime: DateTime.now(),
        points: [
          TrackPoint(lat: 15.5, lon: -88.0, time: DateTime.now()),
          TrackPoint(lat: 15.5001, lon: -88.0, time: DateTime.now()),
        ],
      );
      // ~11 meters apart
      expect(track.distanceMeters, greaterThan(8));
      expect(track.distanceMeters, lessThan(15));
    });

    test('distanceMeters es 0 con 0 o 1 puntos', () {
      final empty = GpxTrack(
        name: 'Empty',
        startTime: DateTime.now(),
        points: [],
      );
      expect(empty.distanceMeters, 0);
    });

    test('duration calcula tiempo transcurrido', () {
      final start = DateTime.parse('2025-01-15T10:00:00');
      final end = DateTime.parse('2025-01-15T10:10:00');
      final track = GpxTrack(
        name: 'Test',
        startTime: start,
        points: [
          TrackPoint(lat: 0, lon: 0, time: start),
          TrackPoint(lat: 0, lon: 0, time: end),
        ],
      );
      expect(track.duration.inMinutes, 10);
    });
  });
}
