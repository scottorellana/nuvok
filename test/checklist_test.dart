import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/prep/checklist.dart';

void main() {
  group('ChecklistProgress', () {
    test('total items is reasonable (25+)', () {
      expect(checklistItems.length, greaterThanOrEqualTo(25));
    });

    test('every item has unique id', () {
      final ids = checklistItems.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every item references a valid category', () {
      final catIds = categories.map((c) => c.id).toSet();
      for (final item in checklistItems) {
        expect(catIds.contains(item.category), isTrue,
            reason: '${item.id} references unknown category ${item.category}');
      }
    });

    test('every category has at least 3 items', () {
      for (final cat in categories) {
        final count = checklistItems.where((i) => i.category == cat.id).length;
        expect(count, greaterThanOrEqualTo(3),
            reason: '${cat.id} has only $count items');
      }
    });

    test('itemsForCategory returns correct items', () {
      final waterItems = ChecklistProgress.instance.itemsForCategory('water');
      expect(waterItems, isNotEmpty);
      expect(waterItems.every((i) => i.category == 'water'), isTrue);
    });

    test('totalInCategory matches actual count', () {
      for (final cat in categories) {
        final actual = checklistItems.where((i) => i.category == cat.id).length;
        expect(ChecklistProgress.instance.totalInCategory(cat.id), actual);
      }
    });

    test('item text is non-empty in both languages', () {
      for (final item in checklistItems) {
        expect(item.textEs, isNotEmpty, reason: '${item.id} has empty ES text');
        expect(item.textEn, isNotEmpty, reason: '${item.id} has empty EN text');
      }
    });

    test('category names are non-empty in both languages', () {
      for (final cat in categories) {
        expect(cat.nameEs, isNotEmpty);
        expect(cat.nameEn, isNotEmpty);
      }
    });
  });

  group('ChecklistProgress math', () {
    test('percentComplete is between 0 and 1', () {
      final pct = ChecklistProgress.instance.percentComplete();
      expect(pct, greaterThanOrEqualTo(0.0));
      expect(pct, lessThanOrEqualTo(1.0));
    });

    test('totalCount matches checklistItems', () {
      expect(ChecklistProgress.instance.totalCount(), checklistItems.length);
    });
  });
}
