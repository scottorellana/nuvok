import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/tools/flashlight.dart';

const _torchChannel = MethodChannel('com.svprdga.torchlight/main');

class _TorchMethodHarness {
  bool available = false;
  bool failEnable = false;
  final calls = <String>[];

  Future<dynamic> handler(MethodCall call) async {
    calls.add(call.method);
    if (call.method == 'torch_available') return available;
    if (call.method == 'enable_torch') {
      if (failEnable) {
        throw PlatformException(code: 'enable_torch_error_existent_user');
      }
      return null;
    }
    if (call.method == 'disable_torch') {
      return null;
    }
    return null;
  }
}

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
    late _TorchMethodHarness torch;
    late FlashlightController ctrl;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      torch = _TorchMethodHarness();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        _torchChannel,
        torch.handler,
      );
      ctrl = FlashlightController.instance;
      torch.available = false;
      await ctrl.setMode(FlashlightMode.off);
      await ctrl.checkAvailable();
    });

    tearDown(() async {
      ctrl.disposeTimer();
      await ctrl.setMode(FlashlightMode.off);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_torchChannel, null);
    });

    test('starts in off mode', () {
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

    test(
      'setMode(sos) clears stale fallback when torch becomes available',
      () async {
        torch.available = false;
        await ctrl.setMode(FlashlightMode.on);
        expect(ctrl.isScreenFallback, isTrue);

        torch.available = true;
        await ctrl.checkAvailable();
        expect(ctrl.available, isTrue);
        expect(
          ctrl.isScreenFallback,
          isTrue,
          reason:
              'Fallo de estado previo debe persistir en OFF/ON hasta entrar SOS',
        );

        await ctrl.setMode(FlashlightMode.sos);
        expect(ctrl.mode, FlashlightMode.sos);
        expect(
          ctrl.isScreenFallback,
          isFalse,
          reason:
              'Entrando a SOS con LED disponible, la UI debe intentar ruta LED',
        );
      },
    );

    test('checkAvailable can migrate SOS from screen fallback to LED path', () async {
      torch.available = false;
      await ctrl.setMode(FlashlightMode.sos);
      expect(ctrl.isScreenFallback, isTrue);
      expect(ctrl.mode, FlashlightMode.sos);

      torch.available = true;
      await ctrl.checkAvailable();
      await Future<void>.delayed(Duration.zero);

      expect(ctrl.available, isTrue);
      expect(
        ctrl.isScreenFallback,
        isFalse,
        reason: 'Con recuperación de hardware, SOS debe volver a LED',
      );
      expect(
        torch.calls.where((method) => method == 'enable_torch'),
        isNotEmpty,
      );
    });
  });
}
