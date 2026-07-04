import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/depot/starter_pack.dart';

void main() {
  test('paquetes de contenido cubren áreas clave y son descargables', () {
    final es = StarterPack.itemsFor('spa');
    final en = StarterPack.itemsFor('eng');

    expect(es.length, greaterThanOrEqualTo(5));
    expect(en.length, es.length);

    for (final item in es) {
      expect(item.category, isNotEmpty);
      expect(item.description, isNotEmpty);
      expect(item.queries, isNotEmpty);
    }

    final categories = es.map((i) => i.category.toLowerCase()).join(' ');
    expect(categories, contains('primeros auxilios'));
    expect(categories, contains('supervivencia'));
    expect(categories, contains('agua'));
    expect(categories, contains('desastres'));
    expect(categories, contains('alimentos'));
  });
}
