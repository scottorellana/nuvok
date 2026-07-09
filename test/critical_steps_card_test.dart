import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_guides.dart';
import 'package:prepper_pad/modules/emergency/medical_diagrams.dart';

/// Finds every rendered Text string in the widget tree.
Iterable<String> _allTexts(WidgetTester tester) sync* {
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final d = w.data;
    if (d != null) yield d;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      r'CriticalStepsCard strips **bold** markdown without leaking $1 literal',
      (tester) async {
    const body = '''
## Pasos
1. **Aleja a la persona de la serpiente.** Siéntala y mantén la calma.
2. **Quita anillos y pulseras** del miembro mordido antes de que hinche.
3. **Inmoviliza el miembro** con una férula suave.
''';

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CriticalStepsCard(title: 'Mordeduras', body: body),
      ),
    ));

    final texts = _allTexts(tester).toList();

    // The bug: replaceAll(RegExp, r'$1') emits the literal "$1" instead of the
    // captured group. No rendered step may contain that literal.
    for (final t in texts) {
      expect(t.contains(r'$1'), isFalse,
          reason: 'Rendered step leaked the literal \$1: "$t"');
    }

    // The bold content itself must survive, stripped of the ** markers.
    expect(
      texts.any((t) => t.contains('Aleja a la persona de la serpiente')),
      isTrue,
      reason: 'Bold step text was lost entirely',
    );
    expect(
      texts.any((t) => t.contains('**')),
      isFalse,
      reason: 'Markdown asterisks leaked into the rendered step',
    );
  });

  testWidgets(
      'CriticalStepsCard extracts real donts from a table, not the header',
      (tester) async {
    const body = '''
## Qué NO hacer

| ❌ Error | ✅ Correcto |
|----------|------------|
| Quitar el trapo empapado | Poner otro encima |
| Sacar el objeto clavado | Fijarlo con vendas |

## Otra sección
''';

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CriticalStepsCard(title: 'Hemorragia', body: body),
      ),
    ));

    final texts = _allTexts(tester).toList();

    // The header row must NOT become a warning.
    expect(texts.any((t) => t.contains('Correcto')), isFalse,
        reason: 'Table header leaked as a warning');
    // The real "dont" (first column of data rows) must be shown.
    expect(texts.any((t) => t.contains('Quitar el trapo empapado')), isTrue,
        reason: 'Real warning from the table was not extracted');
  });

  testWidgets(r'every real guide renders critical steps without $1 or markdown',
      (tester) async {
    final guides = await EmergencyGuides.load('es');
    for (final g in guides) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CriticalStepsCard(title: g.title, body: g.body),
          ),
        ),
      ));
      await tester.pump();
      for (final t in _allTexts(tester)) {
        expect(t.contains(r'$1'), isFalse,
            reason: '${g.id} leaked \$1 in a critical step: "$t"');
        expect(t.contains('**'), isFalse,
            reason: '${g.id} leaked ** markdown in a critical step: "$t"');
      }
    }
  });
}
