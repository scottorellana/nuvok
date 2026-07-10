import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/emergency/decision_tree.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el árbol está cerrado (sin nodos colgantes) y arranca en root', () {
    expect(decisionTreeIsClosed(), isTrue);
  });

  test('cada hoja apunta a una guía que EXISTE en es y en', () async {
    final es = {for (final g in await EmergencyGuides.load('es')) g.id};
    final en = {for (final g in await EmergencyGuides.load('en')) g.id};
    for (final id in decisionTreeLeafGuideIds()) {
      expect(es, contains(id), reason: 'guía es/$id no existe');
      expect(en, contains(id), reason: 'guía en/$id no existe');
    }
  });

  test('cada clave i18n del árbol existe en los 7 idiomas', () {
    final keys = <String>{};
    for (final n in decisionTree.values) {
      keys.add(n.questionKey);
      for (final o in n.options) {
        keys.add(o.labelKey);
      }
    }
    for (final k in keys) {
      final entry = AppStrings.allKeys[k];
      expect(entry, isNotNull, reason: 'falta la clave $k');
      for (final lang in ['es', 'en', 'pt', 'fr', 'zh', 'ja', 'ht']) {
        expect(entry![lang], isNotNull, reason: '$k falta idioma $lang');
      }
    }
  });
}
