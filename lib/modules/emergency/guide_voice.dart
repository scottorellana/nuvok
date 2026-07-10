// Lectura en voz alta de guías — manos libres. En una RCP tienes las DOS
// manos en el pecho: la app lee los pasos críticos con el motor TTS offline
// del sistema, numerándolos y con pausa entre pasos.
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Mapea el idioma de la app al locale TTS del sistema. Puro y testeable.
/// Criollo haitiano no existe en los motores TTS comunes → francés, el
/// idioma oficial más cercano de Haití.
String ttsLocaleFor(String appLangCode) => switch (appLangCode) {
      'es' => 'es-ES',
      'en' => 'en-US',
      'pt' => 'pt-BR',
      'fr' => 'fr-FR',
      'zh' => 'zh-CN',
      'ja' => 'ja-JP',
      'ht' => 'fr-FR',
      _ => 'en-US',
    };

/// Construye el guion hablado: título + pasos numerados. Puro y testeable.
List<String> buildSpeechScript(String title, List<String> steps) => [
      title,
      for (final (i, s) in steps.indexed) '${i + 1}. $s',
    ];

class GuideVoice {
  GuideVoice._();
  static final GuideVoice instance = GuideVoice._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> speaking = ValueNotifier(false);
  bool _stopRequested = false;

  /// Lee [title] y los [steps] en secuencia con pausa breve entre pasos.
  /// Llamar de nuevo mientras habla lo detiene (toggle natural del botón).
  Future<void> speakSteps({
    required String title,
    required List<String> steps,
    required String appLangCode,
  }) async {
    if (speaking.value) {
      await stop();
      return;
    }
    _stopRequested = false;
    speaking.value = true;
    try {
      await _tts.setLanguage(ttsLocaleFor(appLangCode));
      // Pausado y claro: bajo pánico la velocidad normal es demasiado rápida.
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSpeakCompletion(true);
      for (final line in buildSpeechScript(title, steps)) {
        if (_stopRequested) break;
        await _tts.speak(line);
        if (_stopRequested) break;
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    } catch (_) {
      // Sin motor TTS (raro): el botón simplemente no habla; la guía visual
      // sigue completa. Nunca tirar el lector por la voz.
    } finally {
      speaking.value = false;
    }
  }

  Future<void> stop() async {
    _stopRequested = true;
    try {
      await _tts.stop();
    } catch (_) {}
    speaking.value = false;
  }
}
