import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/emergency_retriever.dart';

// El modo emergencia debe responder con la guía aunque no haya IA local.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('strictAnswer devuelve pasos de la guía correcta', () async {
    final answer = await EmergencyRetriever.strictAnswer('no respira');
    expect(answer, isNotNull);
    expect(answer!.toLowerCase(), contains('compresiones'));
    expect(answer, contains('RCP'));
    expect(answer, contains('Respuesta directa de la guía'));
  });

  test('strictAnswer en inglés cuando la consulta es en inglés', () async {
    final answer = await EmergencyRetriever.strictAnswer('severe bleeding');
    expect(answer, isNotNull);
    expect(answer!.toLowerCase(), contains('pressure'));
  });

  test('retrieve antepone las guías como fuentes', () async {
    final sources = await EmergencyRetriever.retrieve('quemadura con aceite');
    expect(sources, isNotEmpty);
    expect(sources.first.book, 'Guía de Emergencia');
    expect(sources.first.title.toLowerCase(), contains('quemadura'));
  });

  test('el prompt de emergencia exige pasos y ayuda profesional', () async {
    final sources = await EmergencyRetriever.retrieve('fractura');
    final prompt = EmergencyRetriever.buildEmergencySystemPrompt(sources);
    expect(prompt, contains('MODO EMERGENCIA'));
    expect(prompt, contains('pasos numerados'));
    expect(prompt, contains('ayuda médica'));
    expect(prompt, contains('FUENTES'));
  });
}
