import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<(int, String)> _get(int port, String path) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
    final res = await req.close();
    final body = await res.transform(SystemEncoding().decoder).join();
    return (res.statusCode, body);
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitForServer(int port) async {
  Object? lastError;
  for (var i = 0; i < 30; i++) {
    try {
      final (status, _) = await _get(port, '/api/status');
      if (status == 200) return;
    } catch (e) {
      lastError = e;
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  throw TimeoutException('installer-server no arrancó: $lastError');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('installer-server no expone settings/notas/mesh por /content', () async {
    final node = await Process.run('node', ['--version']);
    if (node.exitCode != 0) {
      markTestSkipped('node no está disponible');
      return;
    }

    final tempHome = Directory.systemTemp.createTempSync('prepper_home_');
    final prepper = Directory('${tempHome.path}/PrepperPad')..createSync();
    File('${prepper.path}/.settings.json')
        .writeAsStringSync('{"secret":"local"}');
    Directory('${prepper.path}/notes').createSync();
    File('${prepper.path}/notes/private.md').writeAsStringSync('nota privada');
    Directory('${prepper.path}/mesh').createSync();
    File('${prepper.path}/mesh/channels.json').writeAsStringSync('[]');
    Directory('${prepper.path}/maps').createSync();
    File('${prepper.path}/maps/ok.pmtiles').writeAsBytesSync([1, 2, 3, 4]);

    final port = await _freePort();
    final proc = await Process.start(
      'node',
      ['installer-server/server.js'],
      workingDirectory: Directory.current.path,
      environment: {'HOME': tempHome.path, 'PORT': '$port'},
    );
    addTearDown(() async {
      proc.kill(ProcessSignal.sigterm);
      await proc.exitCode.timeout(const Duration(seconds: 2), onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return -1;
      });
      tempHome.deleteSync(recursive: true);
    });
    unawaited(proc.stdout.drain<void>());
    unawaited(proc.stderr.drain<void>());

    await _waitForServer(port);

    expect((await _get(port, '/content/maps/ok.pmtiles')).$1, 200);
    expect(
        (await _get(port, '/content/./.settings.json')).$1, isNot(equals(200)));
    expect(
        (await _get(port, '/content/notes/private.md')).$1, isNot(equals(200)));
    expect((await _get(port, '/content/mesh/channels.json')).$1,
        isNot(equals(200)));
    expect((await _get(port, '/content/maps/../.settings.json')).$1,
        isNot(equals(200)));
  });

  test('landing evita buffering JS de instaladores grandes', () {
    final html = File('installer-server/public/index.html').readAsStringSync();

    expect(html, contains('nativeDownloadThreshold = 100 * 1024 * 1024'));
    expect(html, contains('data-size="\${inst.size}"'));
    expect(
        html,
        contains(
            'downloadWithProgress(url, name, progressBar, progressText, btn, expectedSize)'));
    expect(html, contains('startNativeDownload(url, filename)'));
    expect(html, contains('resp.body?.cancel()'));
  });
}
