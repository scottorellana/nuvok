import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';

// El idioma es infraestructura de seguridad aquí: una app de emergencia que
// el usuario no entiende es una app rota. Estos tests fijan la detección del
// idioma del sistema, la cadena de caída y la cobertura de traducciones.
void main() {
  test('fromLocale detecta variantes regionales', () {
    expect(AppLanguage.fromLocale(const Locale('pt', 'BR')), AppLanguage.pt);
    expect(
        AppLanguage.fromLocale(const Locale.fromSubtags(
            languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN')),
        AppLanguage.zh);
    expect(AppLanguage.fromLocale(const Locale('en', 'GB')), AppLanguage.en);
    expect(AppLanguage.fromLocale(const Locale('de')), AppLanguage.es,
        reason: 'idioma no soportado cae a español (público principal)');
  });

  test('fallback: idioma pedido → inglés → español, nunca mezcla rara', () {
    // 'welcomeTitle' existe solo es/en/pt/fr (no es clave core).
    final zh = AppStrings(AppLanguage.zh);
    final en = AppStrings(AppLanguage.en);
    expect(zh.t('welcomeTitle'), en.t('welcomeTitle'),
        reason: 'clave sin 中文 debe caer a inglés, no a español');
    // Clave core sí existe en chino.
    expect(zh.t('emergency'), isNot(en.t('emergency')));
  });

  test('clave inexistente devuelve la clave (visible en dev, no crash)', () {
    expect(AppStrings(AppLanguage.es).t('no_existe_xyz'), 'no_existe_xyz');
  });

  test('cobertura: toda clave tiene es+en; las core tienen los 7 idiomas',
      () {
    expect(AppStrings.allKeys, isNotEmpty);
    for (final entry in AppStrings.allKeys.entries) {
      expect(entry.value['es'], isNotNull, reason: 'falta es: ${entry.key}');
      expect(entry.value['en'], isNotNull, reason: 'falta en: ${entry.key}');
    }
    for (final key in AppStrings.coreKeys) {
      final map = AppStrings.allKeys[key];
      expect(map, isNotNull, reason: 'clave core no registrada: $key');
      for (final lang in AppLanguage.values) {
        expect(map![lang.code], isNotNull,
            reason: 'clave core "$key" sin ${lang.code}');
      }
    }
  });

  test('los getters existentes siguen funcionando (compatibilidad)', () {
    final es = AppStrings(AppLanguage.es);
    expect(es.emergency, 'Emergencia');
    expect(es.sos, 'SOS');
    expect(AppStrings(AppLanguage.ht).comms, 'Kominikasyon');
  });
}
