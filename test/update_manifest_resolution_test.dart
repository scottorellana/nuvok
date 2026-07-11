import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/update/update_service.dart';

void main() {
  test('producción: sin configuración, las actualizaciones vienen de nuvok.org',
      () {
    expect(UpdateService.resolveManifestFrom(const {}),
        'https://nuvok.org/version.json');
  });

  test('un servidor LAN configurado tiene prioridad sobre nuvok.org', () {
    expect(
      UpdateService.resolveManifestFrom(
          const {'localMapServer': 'http://192.168.1.152:8848/'}),
      'http://192.168.1.152:8848/version.json',
    );
  });

  test('un override explícito gana sobre todo', () {
    expect(
      UpdateService.resolveManifestFrom(const {
        'updateManifestUrl': 'https://beta.nuvok.org/version.json',
        'localMapServer': 'http://192.168.1.152:8848',
      }),
      'https://beta.nuvok.org/version.json',
    );
  });
}
