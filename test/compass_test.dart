import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/tools/compass.dart';

void main() {
  group('CompassReading', () {
    test('cardinalDirection N', () {
      const r = CompassReading(heading: 0, accuracy: 1);
      expect(r.cardinalDirection, 'N');
    });

    test('cardinalDirection NNE rounds to N', () {
      const r = CompassReading(heading: 10, accuracy: 1);
      expect(r.cardinalDirection, 'N');
    });

    test('cardinalDirection NE at 45°', () {
      const r = CompassReading(heading: 45, accuracy: 1);
      expect(r.cardinalDirection, 'NE');
    });

    test('cardinalDirection E at 90°', () {
      const r = CompassReading(heading: 90, accuracy: 1);
      expect(r.cardinalDirection, 'E');
    });

    test('cardinalDirection S at 180°', () {
      const r = CompassReading(heading: 180, accuracy: 1);
      expect(r.cardinalDirection, 'S');
    });

    test('cardinalDirection W at 270°', () {
      const r = CompassReading(heading: 270, accuracy: 1);
      expect(r.cardinalDirection, 'W');
    });

    test('cardinalDirection NW at 315°', () {
      const r = CompassReading(heading: 315, accuracy: 1);
      expect(r.cardinalDirection, 'NW');
    });

    test('cardinalDirection wraps N at 360°', () {
      const r = CompassReading(heading: 360, accuracy: 1);
      expect(r.cardinalDirection, 'N');
    });

    test('cardinalDirection boundary 22.5° → NE', () {
      const r = CompassReading(heading: 22.5, accuracy: 1);
      expect(r.cardinalDirection, 'NE');
    });

    test('cardinalDirection boundary 337.5° → N', () {
      const r = CompassReading(heading: 337.5, accuracy: 1);
      expect(r.cardinalDirection, 'N');
    });
  });

  group('CompassMath', () {
    test('normalizeHeading keeps values in 0 inclusive to 360 exclusive', () {
      expect(CompassMath.normalizeHeading(0), 0);
      expect(CompassMath.normalizeHeading(360), 0);
      expect(CompassMath.normalizeHeading(725), 5);
      expect(CompassMath.normalizeHeading(-1), 359);
      expect(CompassMath.normalizeHeading(-720), 0);
    });

    test('circularMean handles north wrap without averaging to south', () {
      final mean = CompassMath.circularMean([359, 1]);
      expect(mean < 2 || mean > 358, isTrue);
    });

    test('circularMean of east-ish readings stays east', () {
      final mean = CompassMath.circularMean([80, 90, 100]);
      expect(mean, closeTo(90, 0.001));
    });
  });

  group('CompassService', () {
    test(
        'feedRawHeading emits normalized smoothed heading with improving accuracy',
        () async {
      final svc = CompassService.createForTest();
      addTearDown(svc.dispose);
      final seen = <CompassReading>[];
      final sub = svc.readings.listen(seen.add);
      addTearDown(sub.cancel);

      svc.feedRawHeading(-1);
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.heading, closeTo(359, 0.001));
      expect(seen.last.cardinalDirection, 'N');
      expect(seen.last.accuracy, 15);

      for (final h in [1.0, 0.0, 2.0, 358.0]) {
        svc.feedRawHeading(h);
      }
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.heading < 3 || seen.last.heading > 357, isTrue);
      expect(seen.last.cardinalDirection, 'N');
      expect(seen.last.accuracy, 5);
    });

    test('feedRawHeading preserves native accuracy and calibration status',
        () async {
      final svc = CompassService.createForTest();
      addTearDown(svc.dispose);
      final seen = <CompassReading>[];
      final sub = svc.readings.listen(seen.add);
      addTearDown(sub.cancel);

      svc.feedRawHeading(
        91,
        accuracyDegrees: 30,
        needsCalibration: true,
        sensorType: 'accelerometer_magnetometer',
      );
      await Future<void>.delayed(Duration.zero);

      expect(seen.last.heading, closeTo(91, 0.001));
      expect(seen.last.accuracy, 30);
      expect(seen.last.needsCalibration, isTrue);
      expect(seen.last.sensorType, 'accelerometer_magnetometer');
    });

    test('feedRawHeading ignores invalid numeric readings', () async {
      final svc = CompassService.createForTest();
      addTearDown(svc.dispose);
      final seen = <CompassReading>[];
      final sub = svc.readings.listen(seen.add);
      addTearDown(sub.cancel);

      svc.feedRawHeading(double.nan);
      svc.feedRawHeading(double.infinity);
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
    });

    test('stop() clears smoothing history to avoid stale post-resume heading',
        () async {
      final svc = CompassService.createForTest();
      addTearDown(svc.dispose);
      final seen = <CompassReading>[];
      final sub = svc.readings.listen(seen.add);
      addTearDown(sub.cancel);

      for (var i = 0; i < 6; i++) {
        svc.feedRawHeading(i.toDouble());
      }
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.accuracy, 5);

      svc.stop();
      svc.feedRawHeading(90);
      await Future<void>.delayed(Duration.zero);

      expect(seen.last.accuracy, 15);
      expect(seen.last.heading, 90);
    });
  });
}
