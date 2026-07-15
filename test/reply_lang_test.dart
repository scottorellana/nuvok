import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/reply_lang.dart';

void main() {
  group('detectReplyLang — es/en principales', () {
    test('pregunta en español gana aunque la app esté en inglés', () {
      expect(
        detectReplyLang('¿Cómo hago un torniquete si mi amigo está sangrando?',
            appLang: 'en'),
        'es',
      );
      expect(
        detectReplyLang('necesito ayuda para purificar el agua del río',
            appLang: 'en'),
        'es',
      );
    });

    test('pregunta en inglés gana aunque la app esté en español', () {
      expect(
        detectReplyLang('how do I treat a burn on my hand?', appLang: 'es'),
        'en',
      );
      expect(
        detectReplyLang('I need help finding clean water', appLang: 'es'),
        'en',
      );
    });

    test('signos exclusivos del español deciden solos', () {
      expect(detectReplyLang('¿RCP?', appLang: 'en'), 'es');
      expect(detectReplyLang('señal de humo', appLang: 'en'), 'es');
    });
  });

  group('detectReplyLang — sin señal clara usa el idioma de la app', () {
    test('texto ambiguo o vacío cae al idioma de la app', () {
      expect(detectReplyLang('SOS', appLang: 'es'), 'es');
      expect(detectReplyLang('SOS', appLang: 'en'), 'en');
      expect(detectReplyLang('', appLang: 'es'), 'es');
      expect(detectReplyLang('12345', appLang: 'ht'), 'ht');
    });
  });

  group('detectReplyLang — otros idiomas de la app', () {
    test('chino y japonés por rango unicode', () {
      expect(detectReplyLang('怎么净化水？', appLang: 'en'), 'zh');
      expect(detectReplyLang('水をきれいにするにはどうすればいいですか', appLang: 'en'), 'ja');
    });

    test('portugués y francés por palabras distintivas', () {
      expect(
        detectReplyLang('preciso de ajuda, não consigo respirar bem',
            appLang: 'en'),
        'pt',
      );
      expect(
        detectReplyLang("j'ai besoin d'aide pour purifier l'eau",
            appLang: 'en'),
        'fr',
      );
    });

    test('kreyòl por palabras distintivas', () {
      expect(
        detectReplyLang('mwen bezwen èd pou jwenn dlo pwòp', appLang: 'en'),
        'ht',
      );
    });
  });
}
