import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/ai/ai_page.dart';
import 'package:prepper_pad/modules/ai/ai_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('estado vacío de IA muestra guía visible cuando hay modelo',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiEmptyState(
            selectedModelPath: '/tmp/qwen2.5-0.5b-instruct-q4_k_m.gguf',
            server: AiEngine.instance,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Modelo local encontrado'), findsOneWidget);
    expect(find.textContaining('qwen2.5-0.5b-instruct-q4_k_m.gguf'),
        findsOneWidget);
    expect(find.textContaining('Pulsa Cargar'), findsOneWidget);
  });
}
