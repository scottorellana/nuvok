// Pasar Nuvok de un teléfono a otro SIN internet.
//
// El problema que resuelve: en un apagón, tu vecino no puede descargar
// Nuvok — no hay red. Pero tú ya la tienes instalada. Este módulo levanta un
// servidor local y muestra un QR: el vecino se conecta a tu WiFi/hotspot,
// escanea y la instala.
//
// Honestidad por plataforma (lo importante aquí):
// - Android: puede servir su PROPIO APK. Funciona de verdad.
// - iOS: Apple NO permite instalar apps desde otra app. Ninguna. Lo decimos
//   claro en vez de ofrecer un botón que no puede funcionar.
// - Escritorio: sirve el instalador si está junto a la app.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ShareCapability {
  /// Puede servir su propio APK a otro teléfono.
  canShareApk,

  /// Apple no permite instalar apps desde otra app.
  cannotShareApple,

  /// Escritorio: comparte el instalador por la red local.
  canShareDesktop,
}

class AppShare {
  AppShare._();

  /// Qué puede hacer esta plataforma. Puro para poder probarlo.
  static ShareCapability capabilityFor({
    required bool isAndroid,
    required bool isIOS,
  }) {
    if (isAndroid) return ShareCapability.canShareApk;
    if (isIOS) return ShareCapability.cannotShareApple;
    return ShareCapability.canShareDesktop;
  }

  static ShareCapability get capability => capabilityFor(
        isAndroid: Platform.isAndroid,
        isIOS: Platform.isIOS,
      );

  /// URL que el vecino abre. null si no hay una IP alcanzable: un QR que
  /// apunta a la nada es peor que no mostrar QR.
  static String? downloadUrl({required String? ip, required int port}) =>
      ip == null ? null : 'http://$ip:$port/';

  /// Elige una IP que OTRO dispositivo pueda alcanzar. Descarta loopback.
  static String? pickLanIp(List<String> addresses) {
    final usable = addresses.where((a) => !a.startsWith('127.')).toList();
    if (usable.isEmpty) return null;
    // Preferir rangos privados típicos (WiFi doméstico o hotspot del móvil).
    for (final prefix in ['192.168.', '10.', '172.']) {
      final match = usable.where((a) => a.startsWith(prefix));
      if (match.isNotEmpty) return match.first;
    }
    return usable.first;
  }

  /// IPs IPv4 reales del dispositivo.
  static Future<List<String>> localAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      return [
        for (final i in interfaces)
          for (final a in i.addresses) a.address,
      ];
    } catch (e) {
      if (kDebugMode) debugPrint('localAddresses falló: $e');
      return const [];
    }
  }
}

/// Servidor local que entrega el instalador a un vecino por WiFi/hotspot.
///
/// Deliberadamente simple: una sola ruta que devuelve el archivo. No hay
/// autenticación porque el "secreto" es estar en la misma red y ver el QR —
/// y porque en una emergencia la fricción cuesta vidas, no datos.
class AppShareServer {
  AppShareServer._();
  static final AppShareServer instance = AppShareServer._();

  HttpServer? _server;
  String? _url;

  bool get running => _server != null;
  String? get url => _url;

  static const int port = 8788;

  /// Arranca el servidor. Devuelve la URL, o null si no se pudo (sin red o
  /// sin instalador a mano).
  Future<String?> start() async {
    if (_server != null) return _url;
    final file = await _installerFile();
    if (file == null || !file.existsSync()) return null;

    final ip = AppShare.pickLanIp(await AppShare.localAddresses());
    if (ip == null) return null;

    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server = server;
      _url = AppShare.downloadUrl(ip: ip, port: port);
      final name = file.uri.pathSegments.last;
      server.listen((req) async {
        try {
          req.response.headers
            ..contentType = ContentType('application', 'vnd.android.package-archive')
            ..add('Content-Disposition', 'attachment; filename="$name"');
          req.response.contentLength = file.lengthSync();
          await file.openRead().pipe(req.response);
        } catch (_) {
          try {
            await req.response.close();
          } catch (_) {}
        }
      });
      return _url;
    } catch (e) {
      if (kDebugMode) debugPrint('AppShareServer.start falló: $e');
      _server = null;
      _url = null;
      return null;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _url = null;
  }

  /// El archivo que se entrega: en Android, el propio APK instalado.
  Future<File?> _installerFile() async {
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('nuvok/app_share');
        final path = await channel.invokeMethod<String>('apkPath');
        return path == null ? null : File(path);
      } catch (_) {
        return null;
      }
    }
    return null; // iOS no puede; escritorio se resuelve aparte.
  }
}
