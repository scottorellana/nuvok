import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_directory.dart';

void main() {
  group('Emergency Directory', () {
    test('tiene al menos 13 países más el universal', () {
      expect(emergencyDirectory.length, greaterThanOrEqualTo(14));
    });

    test('cada país tiene código, nombre, bandera y servicios', () {
      for (final c in emergencyDirectory) {
        expect(c.countryCode, isNotEmpty);
        expect(c.countryName, isNotEmpty);
        expect(c.flag, isNotEmpty);
        expect(c.services, isNotEmpty,
            reason: '${c.countryName} debe tener servicios');
      }
    });

    test('Honduras tiene los números correctos', () {
      final hn = emergencyNumbersFor('HN');
      expect(hn.countryName, 'Honduras');
      expect(hn.services.any((s) => s.number == '911'), isTrue);
      expect(hn.services.any((s) => s.number == '199'), isTrue);
      expect(hn.services.any((s) => s.number == '198'), isTrue);
    });

    test('emergencyNumbersFor encuentra por código ISO', () {
      expect(emergencyNumbersFor('MX').countryName, 'México');
      expect(emergencyNumbersFor('US').countryName, 'Estados Unidos');
      expect(emergencyNumbersFor('ES').countryName, 'España');
      expect(emergencyNumbersFor('CR').countryName, 'Costa Rica');
    });

    test('emergencyNumbersFor con código desconocido retorna universal', () {
      final unknown = emergencyNumbersFor('XX');
      expect(unknown.countryCode, '*');
      expect(unknown.services.any((s) => s.number == '112'), isTrue);
      expect(unknown.services.any((s) => s.number == '911'), isTrue);
    });

    test('emergencyNumbersFor con null retorna universal', () {
      final unknown = emergencyNumbersFor(null);
      expect(unknown.countryCode, '*');
    });

    test('guessCountryFromLatLng detecta Centroamérica', () {
      // San Pedro Sula, Honduras
      expect(guessCountryFromLatLng(15.5041, -88.0250), 'HN');
      // Tegucigalpa, Honduras
      expect(guessCountryFromLatLng(14.0723, -87.2061), 'HN');
      // San Salvador, El Salvador
      expect(guessCountryFromLatLng(13.6929, -89.2182), 'SV');
      // Guatemala City
      expect(guessCountryFromLatLng(14.6349, -90.5069), 'GT');
      // Managua, Nicaragua
      expect(guessCountryFromLatLng(12.1149, -86.2362), 'NI');
    });

    test('guessCountryFromLatLng retorna null para coordenadas lejanas', () {
      expect(guessCountryFromLatLng(0, 0), isNull);
      // Europa
      expect(guessCountryFromLatLng(48.8566, 2.3522), isNull);
    });

    test('guessCountryFromLatLng detecta El Salvador antes que Honduras', () {
      // San Salvador está dentro del bbox de Honduras, debe dar SV
      final result = guessCountryFromLatLng(13.7, -89.2);
      expect(result, 'SV');
    });
  });
}
