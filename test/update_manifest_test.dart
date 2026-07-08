import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/update/update_manifest.dart';

// El comparador semver decide si mostramos el banner de actualización — un
// error aquí implica molestar al usuario de más, o peor, no avisarle nunca.
void main() {
  group('compareSemver', () {
    test('detecta versión más nueva', () {
      expect(compareSemver('0.2.1', '0.2.0') > 0, isTrue);
      expect(compareSemver('1.0.0', '0.9.9') > 0, isTrue);
      expect(compareSemver('0.10.0', '0.9.0') > 0, isTrue);
    });

    test('detecta versión igual', () {
      expect(compareSemver('0.2.0', '0.2.0'), 0);
    });

    test('detecta versión más vieja', () {
      expect(compareSemver('0.1.9', '0.2.0') < 0, isTrue);
    });

    test('ignora sufijo de build number', () {
      expect(compareSemver('0.2.1+5', '0.2.1'), 0);
      expect(compareSemver('0.2.1+5', '0.2.0') > 0, isTrue);
    });

    test('tolera componentes faltantes', () {
      expect(compareSemver('0.2', '0.2.0'), 0);
      expect(compareSemver('1', '0.9.9') > 0, isTrue);
    });
  });

  group('UpdateManifest.fromJson', () {
    test('parsea manifiesto completo con varias plataformas', () {
      final m = UpdateManifest.fromJson({
        'version': '0.2.1',
        'notes': 'Batería real y linterna con LED.',
        'platforms': {
          'macos': {
            'url': 'https://example.com/PrepperPad-0.2.1.dmg',
            'sha256':
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'sizeBytes': 33500000,
          },
          'android': {
            'url': 'https://example.com/prepper-pad-0.2.1.apk',
            'sha256':
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'sizeBytes': 70487939,
          },
        },
      });
      expect(m.version, '0.2.1');
      expect(m.notes, contains('Batería'));
      expect(m.platforms['macos']!.sha256,
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      expect(m.platforms['macos']!.sizeBytes, 33500000);
      expect(m.platforms['android']!.sha256,
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
      expect(m.platforms['android']!.sizeBytes, 70487939);
      expect(m.platforms['windows'], isNull);
    });

    test('tolera manifiesto sin notes ni platforms', () {
      final m = UpdateManifest.fromJson({'version': '0.2.1'});
      expect(m.notes, '');
      expect(m.platforms, isEmpty);
    });

    test('acepta size legacy del servidor LAN además de sizeBytes', () {
      final m = UpdateManifest.fromJson({
        'version': '0.2.5',
        'platforms': {
          'android': {
            'url': '/download/prepper-pad-v0.2.5.apk',
            'sha256':
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'size': 70487939,
          },
        },
      });
      expect(m.platforms['android']!.sizeBytes, 70487939);
    });
  });
}
