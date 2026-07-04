import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('todas las guías embebidas tienen ejemplo práctico offline', () async {
    final es = await EmergencyGuides.load('es');
    final en = await EmergencyGuides.load('en');

    expect(es, isNotEmpty);
    expect(en.length, es.length);

    for (final guide in es) {
      expect(
        guide.body,
        contains('## Ejemplo'),
        reason: '${guide.id} debe incluir un ejemplo práctico en español',
      );
    }
    for (final guide in en) {
      expect(
        guide.body,
        contains('## Example'),
        reason: '${guide.id} debe incluir un ejemplo práctico en inglés',
      );
    }
  });
}
