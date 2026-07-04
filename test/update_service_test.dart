import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:prepper_pad/core/prepper_library.dart';
import 'package:prepper_pad/modules/update/update_service.dart';

/// download() asks path_provider for the app-support directory to stash
/// updates in; the plugin has no real implementation in a widget test
/// (there's no OS to ask), so we back it with an actual temp folder.
class _FakePathProvider extends PathProviderPlatform {
  final String tempPath = Directory.systemTemp
      .createTempSync('prepper_update_test_')
      .path;

  @override
  Future<String?> getApplicationSupportPath() async => tempPath;
}

// End-to-end test against a real local HTTP server (no mocks): serves a
// manifest and a fake asset, then drives UpdateService.check()/download()
// exactly as the app would over a real internet connection. This is what
// proves the whole "download the update when you have internet" promise
// actually works, not just that the JSON parses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test installs an HttpOverrides that fakes every HttpClient
  // request with a 400 — necessary to keep unrelated widget tests from
  // hitting the network by accident, but this suite's whole point is
  // exercising a REAL HttpClient against a REAL local server.
  HttpOverrides.global = null;
  PathProviderPlatform.instance = _FakePathProvider();

  late HttpServer server;
  late int port;
  final assetBytes = Uint8List.fromList(List.generate(5000, (i) => i % 256));
  final assetSha256 = sha256.convert(assetBytes).toString();
  const platformKey = 'macos'; // this test suite runs on the host OS (macOS CI runner or dev Mac)

  setUp(() async {
    await PrepperLibrary.init();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
    server.listen((req) async {
      if (req.uri.path == '/version.json') {
        final manifest = jsonEncode({
          'version': '9.9.9',
          'notes': 'prueba',
          'platforms': {
            platformKey: {
              'url': 'http://127.0.0.1:$port/asset.bin',
              'sha256': assetSha256,
              'sizeBytes': assetBytes.length,
            },
          },
        });
        req.response.headers.contentType = ContentType.json;
        req.response.write(manifest);
        await req.response.close();
      } else if (req.uri.path == '/asset.bin') {
        req.response.add(assetBytes);
        await req.response.close();
      } else if (req.uri.path == '/broken.json') {
        req.response.write('{not valid json');
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('check() detecta una versión más nueva desde un manifiesto real',
      () async {
    final svc = UpdateService.instance;
    svc.currentVersion = '0.2.1'; // older than the served 9.9.9
    await svc.setManifestUrl('http://127.0.0.1:$port/version.json');
    await svc.check();
    expect(svc.state, anyOf(UpdateState.available, UpdateState.upToDate),
        reason: 'debe resolver a un estado terminal, no quedarse cargando');
    // On non-macOS test runners there's no asset for this platform, so we
    // only assert "available" when we know the platform key matches.
    if (Platform.isMacOS) {
      expect(svc.state, UpdateState.available);
      expect(svc.latest?.version, '9.9.9');
    }
  });

  test('check() cae a error limpio con un manifiesto corrupto', () async {
    final svc = UpdateService.instance;
    await svc.setManifestUrl('http://127.0.0.1:$port/broken.json');
    await svc.check();
    expect(svc.state, UpdateState.error);
    expect(svc.error, isNotNull);
  });

  test('check() cae a error limpio sin servidor (offline)', () async {
    final svc = UpdateService.instance;
    // Port 1 on loopback: connection refused immediately, simulating "no
    // internet" — the whole point is this must never throw uncaught.
    await svc.setManifestUrl('http://127.0.0.1:1/version.json');
    await svc.check();
    expect(svc.state, UpdateState.error);
  });

  test('download() escribe el archivo y verifica el sha256 correctamente',
      () async {
    final svc = UpdateService.instance;
    svc.currentVersion = '0.0.1';
    await svc.setManifestUrl('http://127.0.0.1:$port/version.json');
    await svc.check();
    if (!Platform.isMacOS) return; // asset only registered for 'macos' above
    expect(svc.state, UpdateState.available);
    await svc.download();
    expect(svc.state, UpdateState.downloaded);
    expect(svc.downloadedFile, isNotNull);
    final onDisk = await svc.downloadedFile!.readAsBytes();
    expect(onDisk, assetBytes);
  });

  test('download() rechaza un archivo con sha256 que no coincide', () async {
    // Point the manifest's checksum at a wrong value while serving the
    // same bytes — download() must refuse to hand this to the installer.
    final badServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final badPort = badServer.port;
    badServer.listen((req) async {
      if (req.uri.path == '/version.json') {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'version': '9.9.9',
          'platforms': {
            'macos': {
              'url': 'http://127.0.0.1:$badPort/asset.bin',
              'sha256': '0' * 64, // deliberately wrong
              'sizeBytes': assetBytes.length,
            },
          },
        }));
      } else {
        req.response.add(assetBytes);
      }
      await req.response.close();
    });
    addTearDown(() => badServer.close(force: true));

    if (!Platform.isMacOS) return;
    final svc = UpdateService.instance;
    svc.currentVersion = '0.0.1';
    await svc.setManifestUrl('http://127.0.0.1:$badPort/version.json');
    await svc.check();
    expect(svc.state, UpdateState.available);
    await svc.download();
    expect(svc.state, UpdateState.error);
    expect(svc.error, contains('Verificación'));
  });
}
