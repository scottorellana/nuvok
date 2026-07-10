import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ejemplos de guías son escenarios accionables y fáciles de seguir',
      () async {
    final es = await EmergencyGuides.load('es');
    final en = await EmergencyGuides.load('en');

    for (final guide in es) {
      final example = _section(guide.body, '## Ejemplo');
      expect(example.length, greaterThan(420), reason: guide.id);
      for (final marker in ['Situación:', 'Haz:', 'Evita:', 'Escala:']) {
        expect(example, contains(marker), reason: '${guide.id} falta $marker');
      }
      expect(example, matches(RegExp(r'1\.|2\.|3\.')), reason: guide.id);
    }

    for (final guide in en) {
      final example = _section(guide.body, '## Example');
      expect(example.length, greaterThan(420), reason: guide.id);
      for (final marker in ['Situation:', 'Do:', 'Avoid:', 'Escalate:']) {
        expect(example, contains(marker),
            reason: '${guide.id} missing $marker');
      }
      expect(example, matches(RegExp(r'1\.|2\.|3\.')), reason: guide.id);
    }
  });
}

String _section(String body, String heading) {
  final start = body.indexOf(heading);
  expect(start, isNonNegative, reason: 'missing $heading');
  final next = body.indexOf('\n## ', start + heading.length);
  return body.substring(start, next == -1 ? body.length : next).trim();
}
