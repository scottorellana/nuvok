import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/depot/app_share.dart';

void main() {
  group('qué puede compartir cada plataforma (honestidad, no promesas)', () {
    test('Android puede pasar su propia app a otro teléfono', () {
      expect(AppShare.capabilityFor(isAndroid: true, isIOS: false),
          ShareCapability.canShareApk);
    });

    test('iOS NO puede instalar apps desde otra app', () {
      // Restricción de Apple, no una limitación nuestra: la pantalla debe
      // decirlo claro en vez de ofrecer un botón que no funciona.
      expect(AppShare.capabilityFor(isAndroid: false, isIOS: true),
          ShareCapability.cannotShareApple);
    });

    test('escritorio comparte el instalador por la red local', () {
      expect(AppShare.capabilityFor(isAndroid: false, isIOS: false),
          ShareCapability.canShareDesktop);
    });
  });

  group('URL de descarga para el vecino', () {
    test('arma una URL usable desde otro teléfono', () {
      final url = AppShare.downloadUrl(ip: '192.168.1.42', port: 8080);
      expect(url, 'http://192.168.1.42:8080/');
    });

    test('sin IP no inventa una URL rota', () {
      expect(AppShare.downloadUrl(ip: null, port: 8080), isNull,
          reason: 'un QR que apunta a la nada es peor que no mostrar QR');
    });

    test('descarta la interfaz de loopback: el vecino no puede alcanzarla', () {
      expect(AppShare.pickLanIp(['127.0.0.1']), isNull);
      expect(AppShare.pickLanIp(['127.0.0.1', '192.168.1.5']), '192.168.1.5');
    });

    test('prefiere una IP de red local sobre otras', () {
      expect(AppShare.pickLanIp(['10.0.0.4']), '10.0.0.4');
      expect(AppShare.pickLanIp(['172.20.10.3']), '172.20.10.3',
          reason: 'rango típico del hotspot de un iPhone');
    });

    test('sin ninguna interfaz utilizable devuelve null', () {
      expect(AppShare.pickLanIp([]), isNull);
    });
  });
}
