import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('todas las guías embebidas tienen ejemplo práctico offline', () async {
    final es = await EmergencyGuides.load('es');
    final en = await EmergencyGuides.load('en');

    expect(es, isNotEmpty);
    expect(en.length, es.length);

    for (final guide in es) {
      expect(
        RegExp(
          r'^## Ejemplo práctico:\s*[^\n]+\s*$',
          multiLine: true,
        ).hasMatch(guide.body),
        isTrue,
        reason: '${guide.id} debe incluir un ejemplo práctico en español',
      );
    }
    for (final guide in en) {
      final heading = RegExp(
        r'^## Example(?:\s*:\s*[^\n]+)?\s*$',
        multiLine: true,
      ).firstMatch(guide.body);
      expect(
        heading,
        isNotNull,
        reason: '${guide.id} debe incluir un ejemplo práctico en inglés',
      );
      if (heading == null) continue;

      final tail = guide.body.substring(heading.end);
      final nextHeading = RegExp(r'^##\s+', multiLine: true).firstMatch(tail);
      final example = tail.substring(0, nextHeading?.start ?? tail.length);
      final lines = example.split('\n');
      for (final marker in const [
        '**Situation:**',
        '**Do:**',
        '**Avoid:**',
        '**Escalate:**',
      ]) {
        expect(
          lines.any((line) => line == marker || line.startsWith('$marker ')),
          isTrue,
          reason: '${guide.id} debe incluir $marker dentro de Example',
        );
      }
    }
  });
}
