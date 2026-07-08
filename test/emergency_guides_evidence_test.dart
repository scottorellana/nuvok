import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_guides.dart';

// Critical first-aid guides must expose their evidence base and safe
// improvisation guidance so future edits do not drift into folk medicine.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const criticalPairs = <String, String>{
    'es/rcp_adulto': 'AHA 2025',
    'en/rcp_adulto': 'AHA 2025',
    'es/hemorragia_severa': 'STOP THE BLEED',
    'en/hemorragia_severa': 'STOP THE BLEED',
    'es/primeros_auxilios_extremos': 'ATLS 2025',
    'en/extreme_first_aid': 'ATLS 2025',
  };

  test('guías críticas declaran evidencia científica actualizada', () async {
    for (final entry in criticalPairs.entries) {
      final path = 'assets/emergency_guides/${entry.key}.md';
      final raw = await rootBundle.loadString(path);
      expect(raw, contains(entry.value),
          reason: '$path sin fuente ${entry.value}');
      expect(
        raw.toLowerCase(),
        anyOf(contains('improvisación'), contains('improvisation')),
        reason: '$path debe incluir improvisación segura',
      );
    }
  });

  test('algoritmo crítico se carga y queda priorizado', () async {
    final es = await EmergencyGuides.load('es');
    final en = await EmergencyGuides.load('en');

    expect(es.map((g) => g.id), contains('primeros_auxilios_extremos'));
    expect(en.map((g) => g.id), contains('extreme_first_aid'));
    expect(
      EmergencyGuides.search(es, 'improvisar torniquete').first.id,
      anyOf('primeros_auxilios_extremos', 'hemorragia_severa'),
    );
  });
}
