import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/sos_alarm.dart';

void main() {
  group('SosAlarmController', () {
    test('starts not alarming', () {
      final ctrl = SosAlarmController.instance;
      expect(ctrl.alarming, isFalse);
    });

    test('trigger sets alarming to true and stores info', () {
      final ctrl = SosAlarmController.instance;
      ctrl.trigger(fromName: 'Juan', note: 'Help!');
      expect(ctrl.alarming, isTrue);
      expect(ctrl.alarmFromName, 'Juan');
      expect(ctrl.alarmNote, 'Help!');
    });

    test('silence resets state', () {
      final ctrl = SosAlarmController.instance;
      ctrl.trigger(fromName: 'Juan', note: 'Help!');
      expect(ctrl.alarming, isTrue);
      ctrl.silence();
      expect(ctrl.alarming, isFalse);
      expect(ctrl.alarmFromName, isNull);
      expect(ctrl.alarmNote, isNull);
    });

    test('repeated trigger does not restart sound loop', () {
      final ctrl = SosAlarmController.instance;
      ctrl.trigger(fromName: 'Juan', note: 'Help!');
      ctrl.trigger(fromName: 'Juan', note: 'Still here!');
      // Should update info but not double-trigger
      expect(ctrl.alarmNote, 'Still here!');
      expect(ctrl.alarming, isTrue);
      ctrl.silence();
    });

    test('trigger with null note works', () {
      final ctrl = SosAlarmController.instance;
      ctrl.trigger(fromName: 'Juan');
      expect(ctrl.alarming, isTrue);
      expect(ctrl.alarmNote, isNull);
      ctrl.silence();
    });

    test('trigger with empty name works', () {
      final ctrl = SosAlarmController.instance;
      ctrl.trigger(note: 'Anon SOS');
      expect(ctrl.alarming, isTrue);
      expect(ctrl.alarmFromName, isNull);
      ctrl.silence();
    });
  });
}
