import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/prompt_budget.dart';

/// Cuando la conversación no cabe en el contexto, algo hay que soltar. Lo que
/// NO se puede soltar es el system prompt: ahí vive la persona del
/// especialista y la regla "NUNCA cambies cifras (tiempos, dosis, cantidades)".
/// Antes se recortaba por el principio, así que eso era justo lo primero en
/// desaparecer — en silencio, y precisamente en las conversaciones largas.
void main() {
  Map<String, String> msg(String role, String content) =>
      {'role': role, 'content': content};

  group('el system prompt es intocable', () {
    test('cabiendo todo, no se toca nada', () {
      final h = [
        msg('system', 'Eres Vera. NUNCA cambies cifras.'),
        msg('user', 'hola'),
        msg('assistant', 'dime'),
        msg('user', '¿cuánto ibuprofeno?'),
      ];
      expect(fitHistory(h, budgetChars: 10000), h);
    });

    test('sin espacio, se sueltan los turnos VIEJOS, no el system', () {
      final system = msg('system', 'Eres Vera. NUNCA cambies cifras.');
      final h = [
        system,
        msg('user', 'a' * 400),
        msg('assistant', 'b' * 400),
        msg('user', 'c' * 400),
        msg('assistant', 'd' * 400),
        msg('user', '¿cuánto ibuprofeno le doy?'),
      ];
      final out = fitHistory(h, budgetChars: 700);

      expect(out.first, system,
          reason: 'sin el system prompt, el especialista médico pierde su '
              'regla de no inventar dosis, y no hay ninguna señal de ello');
      expect(out.last['content'], contains('ibuprofeno'),
          reason: 'la pregunta actual es lo segundo más importante');
    });

    test('la pregunta actual sobrevive aunque sea lo único que quepa', () {
      final h = [
        msg('system', 's' * 300),
        msg('user', 'viejo' * 100),
        msg('user', '¿cuánto ibuprofeno?'),
      ];
      final out = fitHistory(h, budgetChars: 350);
      expect(out.first['role'], 'system');
      expect(out.last['content'], '¿cuánto ibuprofeno?');
      expect(out, hasLength(2), reason: 'lo de en medio es lo prescindible');
    });

    test('se sueltan los turnos por parejas, sin dejar respuestas huérfanas',
        () {
      final h = [
        msg('system', 'sys'),
        msg('user', 'p1' * 200),
        msg('assistant', 'r1' * 200),
        msg('user', 'p2' * 200),
        msg('assistant', 'r2' * 200),
        msg('user', 'p3'),
      ];
      final out = fitHistory(h, budgetChars: 900);
      // Nunca una respuesta sin su pregunta delante.
      for (var i = 1; i < out.length; i++) {
        if (out[i]['role'] == 'assistant') {
          expect(out[i - 1]['role'], 'user',
              reason: 'una respuesta suelta sin su pregunta confunde al modelo');
        }
      }
    });

    test('un system prompt que YA no cabe se recorta por el final, no por el '
        'principio', () {
      // Caso extremo: las fuentes del RAG inflaron el system prompt. Se
      // sacrifican las fuentes (van al final), nunca la persona ni la regla
      // de seguridad (van al principio).
      final system = msg('system',
          'Eres Vera. NUNCA cambies cifras. ${'FUENTE ' * 500}');
      final out = fitHistory([system, msg('user', 'hola')], budgetChars: 200);
      expect(out.first['content'], startsWith('Eres Vera. NUNCA cambies'),
          reason: 'la persona y la regla de seguridad abren el prompt: '
              'recortar por delante las borra');
      expect(out.first['content']!.length, lessThanOrEqualTo(200));
    });

    test('historial vacío o solo system no revienta', () {
      expect(fitHistory(const [], budgetChars: 100), isEmpty);
      final onlySys = [msg('system', 'x')];
      expect(fitHistory(onlySys, budgetChars: 100), onlySys);
    });
  });

  group('presupuesto derivado del contexto', () {
    test('deja sitio para la respuesta', () {
      // n_ctx 4096, 512 de respuesta → el prompt no puede ocuparlo todo.
      final b = promptBudgetChars(nCtx: 4096, maxTokens: 512);
      expect(b, greaterThan(0));
      expect(b, lessThan(4096 * charsPerToken));
    });

    test('más contexto, más presupuesto', () {
      expect(promptBudgetChars(nCtx: 4096, maxTokens: 512),
          greaterThan(promptBudgetChars(nCtx: 2048, maxTokens: 512)));
    });

    test('un contexto absurdamente pequeño no da presupuesto negativo', () {
      expect(promptBudgetChars(nCtx: 128, maxTokens: 512),
          greaterThanOrEqualTo(0));
    });
  });
}
