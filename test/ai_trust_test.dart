import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/ai_trust.dart';

/// Un modelo de 2-4 GB en un teléfono alucina. Estas reglas deciden cuándo
/// el usuario tiene que ver un aviso antes de actuar sobre lo que leyó.
void main() {
  group('procedencia de la respuesta', () {
    test('con fuentes citadas es contenido revisado', () {
      expect(trustOf(hasSources: true), AnswerTrust.grounded);
    });

    test('sin fuentes es contenido generado', () {
      expect(trustOf(hasSources: false), AnswerTrust.generated,
          reason: 'sin fuente el usuario debe saber que puede estar inventado');
    });
  });

  group('terreno clínico en los 7 idiomas', () {
    final debenAvisar = {
      'es': '¿Cuánta dosis de ibuprofeno le doy a un niño?',
      'en': 'What dosage of ibuprofen for a child?',
      'pt': 'Qual a dosagem do remédio para criança?',
      'fr': 'Quelle posologie du médicament pour un enfant?',
      'zh': '孩子应该吃多少剂量的药？',
      'ja': '子供への薬の投与量は？',
      'ht': 'Konbe dòz medikaman pou yon timoun?',
    };

    debenAvisar.forEach((lang, texto) {
      test('$lang: una pregunta sobre dosis exige aviso', () {
        expect(touchesMedical(texto), isTrue,
            reason: 'en $lang una dosis mal dada mata igual');
      });
    });

    test('atrapa por subcadena: dosificación, medicamentos', () {
      expect(touchesMedical('la dosificación correcta'), isTrue);
      expect(touchesMedical('guarda los medicamentos secos'), isTrue);
    });

    test('la respuesta también cuenta, no solo la pregunta', () {
      // Pregunta inocente, respuesta que deriva a terreno clínico.
      expect(touchesMedical('¿qué llevo en la mochila?'), isFalse);
      expect(touchesMedical('Lleva antibióticos y un torniquete'), isTrue);
    });

    test('no avisa en temas que no son clínicos', () {
      for (final t in [
        '¿cómo purifico agua de lluvia?',
        'how do I start a fire with wet wood?',
        '¿qué antena uso para la radio?',
      ]) {
        expect(touchesMedical(t), isFalse, reason: 'aviso de más en: "$t"');
      }
    });
  });

  test('el especialista médico avisa siempre, sin depender de palabras', () {
    expect(agentIsAlwaysMedical('medic'), isTrue);
    expect(agentIsAlwaysMedical('engineer'), isFalse);
  });
}
