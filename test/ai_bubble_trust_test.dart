import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/ai/ai_page.dart';

/// El aviso solo sirve si el usuario LO VE. Estas pruebas entran por la
/// misma puerta que él: la burbuja renderizada.
void main() {
  Future<void> pumpChat(WidgetTester tester, List<ChatMessage> msgs,
      {String agentId = 'engineer'}) async {
    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: Scaffold(
          body: ListView(
            children: [
              for (var i = 0; i < msgs.length; i++)
                debugBubbleForTest(
                  message: msgs[i],
                  agentId: agentId,
                  askedText: i > 0 ? msgs[i - 1].text : '',
                ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('sin fuentes, la respuesta se marca como generada',
      (tester) async {
    await pumpChat(tester, [
      ChatMessage('user', '¿qué antena uso para la radio?'),
      ChatMessage('assistant', 'Una dipolo de media onda funciona bien.'),
    ]);

    expect(find.textContaining('Generado por IA'), findsOneWidget,
        reason: 'sin fuente el usuario debe saber que puede estar inventado');
    expect(find.textContaining('Basado en guías verificadas'), findsNothing);
  });

  testWidgets('una pregunta sobre dosis dispara el aviso médico',
      (tester) async {
    await pumpChat(tester, [
      ChatMessage('user', '¿cuánta dosis de ibuprofeno le doy a un niño?'),
      ChatMessage('assistant', 'Depende del peso.'),
    ]);

    expect(find.textContaining('no reemplaza atención médica'), findsOneWidget,
        reason: 'el aviso debe salir aunque el modelo conteste con evasivas');
  });

  testWidgets('el especialista médico avisa siempre', (tester) async {
    await pumpChat(tester, [
      ChatMessage('user', 'hola'),
      ChatMessage('assistant', 'Cuéntame qué pasa.'),
    ], agentId: 'medic');

    expect(find.textContaining('no reemplaza atención médica'), findsOneWidget);
  });

  testWidgets('una charla técnica no lleva aviso médico', (tester) async {
    await pumpChat(tester, [
      ChatMessage('user', '¿cómo purifico agua de lluvia?'),
      ChatMessage('assistant', 'Hierve el agua cinco minutos.'),
    ]);

    expect(find.textContaining('no reemplaza atención médica'), findsNothing,
        reason: 'un aviso que sale siempre deja de leerse');
  });

  testWidgets('lo que escribe el usuario no lleva sello de procedencia',
      (tester) async {
    await pumpChat(tester, [ChatMessage('user', 'hola')]);
    expect(find.textContaining('Generado por IA'), findsNothing);
  });
}
