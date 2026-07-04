import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_directory.dart';

void main() {
  group('emergencyNumbersFor', () {
    test('returns correct numbers for Honduras', () {
      final result = emergencyNumbersFor('HN');
      expect(result.countryName, 'Honduras');
      expect(result.services, isNotEmpty);
      expect(result.services.any((s) => s.number == '911'), isTrue);
    });

    test('returns correct numbers for El Salvador', () {
      final result = emergencyNumbersFor('SV');
      expect(result.countryName, 'El Salvador');
      expect(result.services.any((s) => s.number == '911'), isTrue);
    });

    test('returns correct numbers for Guatemala', () {
      final result = emergencyNumbersFor('GT');
      expect(result.countryName, 'Guatemala');
      expect(result.services.any((s) => s.name.contains('CONRED')), isTrue);
    });

    test('returns universal fallback for unknown country', () {
      final result = emergencyNumbersFor('XX');
      expect(result.countryCode, '*');
      expect(result.services, isNotEmpty);
    });

    test('returns universal fallback for null country', () {
      final result = emergencyNumbersFor(null);
      expect(result.countryCode, '*');
    });

    test('case insensitive', () {
      final result = emergencyNumbersFor('hn');
      expect(result.countryName, 'Honduras');
    });
  });

  group('guessCountryFromLatLng', () {
    test('Honduras - San Pedro Sula', () {
      expect(guessCountryFromLatLng(15.50, -88.03), 'HN');
    });

    test('Honduras - Tegucigalpa', () {
      expect(guessCountryFromLatLng(14.07, -87.21), 'HN');
    });

    test('El Salvador - San Salvador', () {
      expect(guessCountryFromLatLng(13.69, -89.19), 'SV');
    });

    test('Guatemala - Guatemala City', () {
      expect(guessCountryFromLatLng(14.63, -90.51), 'GT');
    });

    test('Mexico - Mexico City', () {
      expect(guessCountryFromLatLng(19.43, -99.13), 'MX');
    });

    test('Unknown location returns null', () {
      expect(guessCountryFromLatLng(0, 0), isNull);
    });

    test('Atlantic Ocean returns null', () {
      expect(guessCountryFromLatLng(35.0, -45.0), isNull);
    });
  });

  group('EmergencyService', () {
    test('every country has at least one service', () {
      for (final c in emergencyDirectory) {
        expect(c.services, isNotEmpty,
            reason: '${c.countryName} has no services');
      }
    });

    test('every number is non-empty', () {
      for (final c in emergencyDirectory) {
        for (final s in c.services) {
          expect(s.number, isNotEmpty,
              reason: '${c.countryName}/${s.name} has empty number');
        }
      }
    });

    test('country codes are unique', () {
      final codes = emergencyDirectory.map((c) => c.countryCode).toList();
      expect(codes.toSet().length, codes.length);
    });
  });
}
