import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/prep/checklist.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('checklist_expiry_test');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  /// Build a fresh ChecklistProgress that reads/writes to [tmpDir].
  ChecklistProgress freshProgress() {
    // Force a reload by using reflection-free approach: create a new
    // instance via the for-test pattern used elsewhere in this codebase.
    final p = ChecklistProgress.forTest(tmpDir.path);
    return p;
  }

  group('Expiry — data model', () {
    test('food and medical items have expiryMonths > 0', () {
      for (final item in checklistItems) {
        if (item.category == 'food' || item.category == 'medical') {
          expect(item.expiryMonths, greaterThan(0),
              reason: '${item.id} in ${item.category} should expire');
        }
      }
    });

    test('non-perishable items have expiryMonths == 0', () {
      for (final item in checklistItems) {
        if (item.category == 'docs' || item.category == 'plan') {
          expect(item.expiryMonths, 0,
              reason: '${item.id} should not expire');
        }
      }
    });

    test('battery and light items have expiryMonths > 0', () {
      final battery = checklistItems.firstWhere((i) => i.id == 'tool_6');
      expect(battery.expiryMonths, greaterThan(0));
    });
  });

  group('Expiry — progress tracking', () {
    test('setExpiry stores date for an item', () {
      final p = freshProgress();
      final date = DateTime.now().add(const Duration(days: 180));
      p.setExpiry('med_2', date);

      final stored = p.getExpiry('med_2');
      expect(stored, isNotNull);
      expect(stored!.year, date.year);
      expect(stored.month, date.month);
      expect(stored.day, date.day);
    });

    test('daysUntilExpiry returns positive number for future date', () {
      final p = freshProgress();
      p.setExpiry('med_2', DateTime.now().add(const Duration(days: 90)));

      final days = p.daysUntilExpiry('med_2');
      expect(days, greaterThan(85));
      expect(days, lessThan(95));
    });

    test('daysUntilExpiry returns negative for past date', () {
      final p = freshProgress();
      p.setExpiry('med_2', DateTime.now().subtract(const Duration(days: 30)));

      expect(p.daysUntilExpiry('med_2'), lessThan(-25));
    });

    test('daysUntilExpiry returns null when no date set', () {
      final p = freshProgress();
      expect(p.daysUntilExpiry('med_2'), isNull);
    });

    test('isExpired returns true for past date', () {
      final p = freshProgress();
      p.setExpiry('med_2', DateTime.now().subtract(const Duration(days: 1)));
      expect(p.isExpired('med_2'), isTrue);
    });

    test('isExpired returns false for future date', () {
      final p = freshProgress();
      p.setExpiry('med_2', DateTime.now().add(const Duration(days: 100)));
      expect(p.isExpired('med_2'), isFalse);
    });

    test('isNearExpiry returns true within 30 days threshold', () {
      final p = freshProgress();
      p.setExpiry('med_2', DateTime.now().add(const Duration(days: 20)));
      expect(p.isNearExpiry('med_2'), isTrue);
    });

    test('isNearExpiry returns false beyond 30 days', () {
      final p = freshProgress();
      p.setExpiry('med_2', DateTime.now().add(const Duration(days: 60)));
      expect(p.isNearExpiry('med_2'), isFalse);
    });

    test('expiringItems returns items expiring within N days', () {
      final p = freshProgress();
      p.setExpiry('med_1', DateTime.now().add(const Duration(days: 10)));
      p.setExpiry('med_2', DateTime.now().add(const Duration(days: 25)));
      p.setExpiry('food_1', DateTime.now().add(const Duration(days: 100)));

      final expiring = p.expiringItems(withinDays: 30);
      final ids = expiring.map((e) => e.item.id).toList();
      expect(ids, contains('med_1'));
      expect(ids, contains('med_2'));
      expect(ids, isNot(contains('food_1')));
    });

    test('expiredItems returns only past-due items', () {
      final p = freshProgress();
      p.setExpiry('med_1', DateTime.now().subtract(const Duration(days: 5)));
      p.setExpiry('med_2', DateTime.now().add(const Duration(days: 10)));

      final expired = p.expiredItems();
      expect(expired.length, 1);
      expect(expired.first.item.id, 'med_1');
    });
  });

  group('Expiry — persistence', () {
    test('expiry dates survive save/reload', () {
      final p1 = freshProgress();
      p1.setExpiry('med_2', DateTime.now().add(const Duration(days: 45)));
      p1.saveNow();

      final p2 = freshProgress();
      expect(p2.daysUntilExpiry('med_2'), isNotNull);
      expect(p2.daysUntilExpiry('med_2')! > 40, isTrue);
    });

    test('suggestedExpiryForItem returns months-based date', () {
      final med = checklistItems.firstWhere((i) => i.id == 'med_2');
      final suggested = ChecklistProgress.suggestedExpiryForItem(med);
      if (med.expiryMonths > 0) {
        final diff = suggested.difference(DateTime.now()).inDays;
        expect(diff, greaterThan(med.expiryMonths * 28));
        expect(diff, lessThan(med.expiryMonths * 31));
      }
    });

    test('toggle marks done and auto-assigns suggested expiry', () {
      final p = freshProgress();
      p.toggle('med_2');
      expect(p.done.contains('med_2'), isTrue);
      // Auto-expiry should have been set since med_2 has expiryMonths > 0
      expect(p.daysUntilExpiry('med_2'), isNotNull);
    });

    test('toggle off clears expiry', () {
      final p = freshProgress();
      p.toggle('med_2'); // on
      expect(p.daysUntilExpiry('med_2'), isNotNull);
      p.toggle('med_2'); // off
      expect(p.daysUntilExpiry('med_2'), isNull);
    });

    test('old format (bare list) loads without crash', () {
      final file = File('${tmpDir.path}/checklist.json');
      file.writeAsStringSync(jsonEncode(['med_1', 'water_1', 'food_1']));
      final p = freshProgress();
      expect(p.done, contains('med_1'));
      expect(p.done, contains('water_1'));
    });

    test('clearExpiry removes the date for an item', () {
      final p = freshProgress();
      p.setExpiry('med_2', DateTime.now().add(const Duration(days: 90)));
      expect(p.getExpiry('med_2'), isNotNull);
      p.clearExpiry('med_2');
      expect(p.getExpiry('med_2'), isNull);
    });
  });
}
