import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_numbers.dart';

void main() {
  test('devuelve el número correcto por país', () {
    expect(EmergencyNumbers.primaryFor('HN'), '911');
    expect(EmergencyNumbers.primaryFor('US'), '911');
    expect(EmergencyNumbers.primaryFor('MX'), '911');
    expect(EmergencyNumbers.primaryFor('ES'), '112');
    expect(EmergencyNumbers.primaryFor('FR'), '112');
    expect(EmergencyNumbers.primaryFor('JP'), '119');
    expect(EmergencyNumbers.primaryFor('GB'), '999');
    expect(EmergencyNumbers.primaryFor('BR'), '190');
    expect(EmergencyNumbers.primaryFor('CN'), '120');
  });

  test('país desconocido cae al 112 (estándar GSM global)', () {
    expect(EmergencyNumbers.primaryFor('ZZ'), '112');
    expect(EmergencyNumbers.primaryFor(''), '112');
  });

  test('extrae el país del locale del dispositivo', () {
    expect(EmergencyNumbers.countryFromLocale('es_HN'), 'HN');
    expect(EmergencyNumbers.countryFromLocale('en-US'), 'US');
    expect(EmergencyNumbers.countryFromLocale('es'), '');
    expect(EmergencyNumbers.countryFromLocale('zh_Hans_CN'), 'CN');
  });
}
