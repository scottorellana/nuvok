import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/core/locale_service.dart';

// El asistente debe hablar el idioma de la app: cada idioma soportado tiene
// su system prompt que FIJA el idioma de respuesta (los modelos 1B obedecen
// mejor una instrucción explícita que "responde en el idioma del usuario").
// Las claves de estado del chat existen en los 4 idiomas completos.
void main() {
  test('las claves de estado del asistente existen (ES/EN/PT/FR)', () {
    for (final key in ['aiSearchingGuides', 'aiSearchingLibrary']) {
      final map = AppStrings.allKeys[key];
      expect(map, isNotNull, reason: 'clave $key registrada');
      for (final lang in ['es', 'en', 'pt', 'fr']) {
        expect(map![lang], isNotNull, reason: '$key sin $lang');
      }
    }
  });
}
