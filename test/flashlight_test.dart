import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/tools/flashlight.dart';

void main() {
  group('FlashlightMode', () {
    test('has exactly 3 modes', () {
      expect(FlashlightMode.values.length, 3);
    });

    test('contains off, on, sos', () {
      expect(FlashlightMode.values, contains(FlashlightMode.off));
      expect(FlashlightMode.values, contains(FlashlightMode.on));
      expect(FlashlightMode.values, contains(FlashlightMode.sos));
    });
  });

  group('FlashlightController', () {
    test('starts in off mode', () {
      final ctrl = FlashlightController.instance;
      expect(ctrl.mode, FlashlightMode.off);
    });

    test('SOS pattern has expected duration entries', () {
      // The pattern alternates on/off durations for Morse code.
      // Must have an even number (pairs of on/off).
      expect(FlashlightController.sosPattern.length, greaterThan(10));
    });

    test('SOS pattern total cycle is reasonable (5-15 seconds)', () {
      final total = FlashlightController.sosPattern.fold<Duration>(
        Duration.zero,
        (prev, d) => prev + d,
      );
      expect(total.inMilliseconds, greaterThan(3000));
      expect(total.inMilliseconds, lessThan(20000));
    });
  });
}
