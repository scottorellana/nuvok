import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/guide_voice.dart';
import 'package:prepper_pad/modules/emergency/medical_diagrams.dart';

void main() {
  test('ttsLocaleFor cubre los 7 idiomas de la app', () {
    expect(ttsLocaleFor('es'), 'es-ES');
    expect(ttsLocaleFor('en'), 'en-US');
    expect(ttsLocaleFor('pt'), 'pt-BR');
    expect(ttsLocaleFor('fr'), 'fr-FR');
    expect(ttsLocaleFor('zh'), 'zh-CN');
    expect(ttsLocaleFor('ja'), 'ja-JP');
    // Criollo: sin TTS nativo en los motores comunes → francés.
    expect(ttsLocaleFor('ht'), 'fr-FR');
    expect(ttsLocaleFor('xx'), 'en-US');
  });

  test('el guion hablado numera los pasos tras el título', () {
    final script = buildSpeechScript('RCP Adulto', ['Llama ayuda', 'Comprime']);
    expect(script, ['RCP Adulto', '1. Llama ayuda', '2. Comprime']);
  });

  test('extractCriticalSteps sigue limpiando markdown para la voz', () {
    final steps = extractCriticalSteps('1. **Llama al 911** — pide ambulancia\n'
        '2. Comprime fuerte\n');
    expect(steps, ['Llama al 911', 'Comprime fuerte']);
  });
}
