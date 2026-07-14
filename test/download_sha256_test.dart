import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/depot/download_manager.dart';

void main() {
  test('descarga con sha256 correcto queda "done"; con incorrecto, "error"',
      () async {
    final body = List<int>.generate(2048, (i) => i % 256);
    final good = sha256.convert(body).toString();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) {
      req.response
        ..add(body)
        ..close();
    });
    final url = 'http://127.0.0.1:${server.port}/model.gguf';
    final dir = await Directory.systemTemp.createTemp('dl');
    final dm = DownloadManager.instance;

    // sha256 correcto → archivo final presente
    final okPath = '${dir.path}/ok.gguf';
    dm.enqueue(url, okPath, sha256Hex: good);
    await _waitFile(okPath);
    expect(File(okPath).existsSync(), isTrue);

    // sha256 incorrecto → no debe dejar el archivo final
    final badPath = '${dir.path}/bad.gguf';
    dm.enqueue(url, badPath, sha256Hex: 'deadbeef');
    await _waitError(dm, badPath);
    expect(File(badPath).existsSync(), isFalse);
    expect(File('$badPath.part').existsSync(), isFalse,
        reason: 'el .part corrupto debe borrarse');

    await server.close(force: true);
  });
}

Future<void> _waitFile(String path) async {
  for (var i = 0; i < 100; i++) {
    if (File(path).existsSync()) return;
    await Future.delayed(const Duration(milliseconds: 50));
  }
  fail('la descarga no completó');
}

Future<void> _waitError(DownloadManager dm, String path) async {
  for (var i = 0; i < 100; i++) {
    final t = dm.tasks.where((t) => t.destPath == path);
    if (t.isNotEmpty && t.first.status == DownloadStatus.error) return;
    await Future.delayed(const Duration(milliseconds: 50));
  }
  fail('la descarga no marcó error');
}
