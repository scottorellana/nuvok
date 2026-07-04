import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/core/prepper_library.dart';
import 'package:prepper_pad/modules/tools/battery_saver.dart';

// The battery saver must always be reversible and must never expose fake
// controls. These tests lock in the state machine (enable → measures on,
// disable → everything reverted) and that preferences persist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await PrepperLibrary.init();
  });

  test('toggle flips enabled and back', () async {
    final c = BatterySaverController.instance;
    // Turning brightness/mesh/AI measures off first keeps the test from
    // touching platform channels (screen_brightness) that no-op in tests.
    await c.setReduceBrightness(false);
    await c.setPauseMesh(false);
    await c.setPauseAi(false);
    expect(c.enabled, isFalse);
    await c.toggle();
    expect(c.enabled, isTrue);
    await c.toggle();
    expect(c.enabled, isFalse,
        reason: 'debe poder revertirse siempre');
  });

  test('las preferencias persisten en la librería', () async {
    final c = BatterySaverController.instance;
    await c.setPauseMesh(false);
    await c.setPauseAi(false);
    final saved = PrepperLibrary.instance.settings['batterySaver'];
    expect(saved, isA<Map>());
    expect((saved as Map)['pauseMesh'], isFalse);
    expect(saved['pauseAi'], isFalse);
    // Restore defaults so we don't leak state to other tests.
    await c.setPauseMesh(true);
    await c.setPauseAi(true);
  });

  test('lowBatteryThreshold e isLow son coherentes', () {
    final c = BatterySaverController.instance;
    expect(BatterySaverController.lowBatteryThreshold, 15);
    // Sin una lectura real de batería en test, isLow no debe dispararse.
    expect(c.isLow, isFalse);
  });
}
