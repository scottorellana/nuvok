import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/depot/download_manager.dart';

/// Descargar un modelo de 2 GB por la red de un apagón se interrumpe SIEMPRE.
/// Lo que decide si la app sirve es qué pasa al reanudar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // El binding de test intercepta HttpClient y responde 400 a todo. Aquí el
  // objeto bajo prueba ES el cliente HTTP contra un servidor real de loopback:
  // sin esto no se estaría probando nada.
  setUpAll(() => HttpOverrides.global = null);

  late Directory tmp;
  late HttpServer server;

  /// Contenido que sirve el servidor. Los tests lo cambian a mitad para
  /// simular que el archivo remoto se actualizó entre sesiones.
  late List<int> body;
  late String etag;

  /// Cuántos bytes ha servido el servidor en total. Es la única forma de
  /// afirmar que hubo reanudación DE VERDAD y no una descarga entera
  /// disfrazada de éxito.
  var served = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('nuvok_dl');
    body = utf8.encode('A' * 2000);
    etag = '"v1"';
    served = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = req.response;
      res.headers.set(HttpHeaders.etagHeader, etag);
      final range = req.headers.value(HttpHeaders.rangeHeader);
      final ifRange = req.headers.value('if-range');

      if (range != null) {
        final from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        // If-Range: si el validador no coincide, el servidor DEBE ignorar el
        // Range y mandar el archivo entero (RFC 9110 §13.1.5).
        if (ifRange != null && ifRange != etag) {
          res.statusCode = HttpStatus.ok;
          res.headers.contentType = ContentType.binary;
          served += body.length;
          res.add(body);
          await res.close();
          return;
        }
        if (from >= body.length) {
          res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          await res.close();
          return;
        }
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(HttpHeaders.contentRangeHeader,
            'bytes $from-${body.length - 1}/${body.length}');
        served += body.length - from;
        res.add(body.sublist(from));
        await res.close();
        return;
      }
      res.statusCode = HttpStatus.ok;
      served += body.length;
      res.add(body);
      await res.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    DownloadManager.instance.tasks.clear();
  });

  String url() => 'http://127.0.0.1:${server.port}/paquete.bin';
  String dest() => '${tmp.path}/paquete.bin';

  /// Espera a que la tarea termine (bien o mal) sin dormir a ciegas.
  Future<DownloadTask> settle() async {
    final dm = DownloadManager.instance;
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      final t = dm.tasks.isEmpty ? null : dm.tasks.last;
      if (t != null &&
          (t.status == DownloadStatus.done ||
              t.status == DownloadStatus.error)) {
        return t;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return DownloadManager.instance.tasks.last;
  }

  test('reanuda donde quedó cuando el archivo remoto NO cambió', () async {
    // Medio archivo ya bajado en una sesión anterior, con su ficha: es lo que
    // deja la propia app al interrumpirse.
    File('${dest()}.part').writeAsBytesSync(body.sublist(0, 1000));
    File('${dest()}.part.meta').writeAsStringSync(jsonEncode({
      'url': url(),
      'destPath': dest(),
      'validator': etag,
    }));

    DownloadManager.instance.enqueue(url(), dest());
    final t = await settle();

    expect(t.status, DownloadStatus.done, reason: t.error ?? '');
    expect(File(dest()).readAsBytesSync(), body,
        reason: 'reanudar debe reconstruir el archivo exacto');
    expect(served, lessThan(body.length),
        reason: 'bajó el archivo entero: la reanudación no sirvió de nada, y '
            'sobre un modelo de 2 GB eso es la diferencia entre usable y no');
    expect(served, body.length - 1000);
  });

  test('sin ficha y sin hash, el trozo huérfano se tira en vez de empalmarse',
      () async {
    // Un .part sin ficha no se puede atribuir a ninguna versión del recurso.
    File('${dest()}.part').writeAsBytesSync(utf8.encode('Z' * 1000));

    DownloadManager.instance.enqueue(url(), dest());
    final t = await settle();

    expect(t.status, DownloadStatus.done, reason: t.error ?? '');
    expect(File(dest()).readAsBytesSync(), body,
        reason: 'un trozo que no se puede atribuir no vale ni un byte');
  });

  test('la ficha no sobrevive a la descarga terminada', () async {
    DownloadManager.instance.enqueue(url(), dest());
    await settle();
    expect(File('${dest()}.part.meta').existsSync(), isFalse,
        reason: 'una ficha huérfana haría reanudar sobre un archivo que ya '
            'no existe');
  });

  test('si el archivo remoto cambió, NO pega bytes de dos versiones',
      () async {
    // .part de la versión vieja.
    File('${dest()}.part').writeAsBytesSync(utf8.encode('B' * 1000));
    // El servidor ahora sirve otra cosa, con otro validador.
    body = utf8.encode('C' * 2000);
    etag = '"v2"';

    DownloadManager.instance.enqueue(url(), dest());
    final t = await settle();

    expect(t.status, DownloadStatus.done, reason: t.error ?? '');
    final got = File(dest()).readAsBytesSync();
    expect(got, body,
        reason: 'sin If-Range se pegan bytes de dos versiones y sale un '
            'archivo del tamaño correcto con contenido Frankenstein');
    expect(utf8.decode(got).contains('B'), isFalse,
        reason: 'no puede quedar ni un byte de la versión vieja');
  });

  test('un .part más grande que el remoto no se da por bueno', () async {
    // Un .part corrupto/sobrante más largo que el archivo real: el servidor
    // responde 416. Darlo por completo renombra basura a definitivo.
    File('${dest()}.part').writeAsBytesSync(utf8.encode('X' * 5000));

    DownloadManager.instance.enqueue(url(), dest());
    final t = await settle();

    if (t.status == DownloadStatus.done) {
      expect(File(dest()).readAsBytesSync(), body,
          reason: 'se dio por buena una descarga corrupta de 5000 bytes');
    }
  });

  test('la verificación sha256 sigue atrapando un archivo alterado', () async {
    final malHash = sha256.convert(utf8.encode('otra cosa')).toString();
    DownloadManager.instance.enqueue(url(), dest(), sha256Hex: malHash);
    final t = await settle();

    expect(t.status, DownloadStatus.error);
    expect(File(dest()).existsSync(), isFalse,
        reason: 'un archivo que no cuadra no puede quedar instalado');
  });

  group('la cola sobrevive al cierre de la app', () {
    test('reencola lo que quedó a medias', () {
      File('${dest()}.part').writeAsBytesSync(utf8.encode('A' * 500));
      File('${dest()}.part.meta').writeAsStringSync(jsonEncode({
        'url': url(),
        'destPath': dest(),
        'validator': etag,
        'totalBytes': 2000,
      }));

      final n = DownloadManager.instance.restoreQueue(tmp);
      expect(n, 1, reason: 'los gigabytes ya bajados quedaban huérfanos');
      expect(DownloadManager.instance.tasks.single.url, url());
    });

    test('una ficha sin su trozo no reencola nada y se limpia sola', () {
      final meta = File('${dest()}.part.meta')
        ..writeAsStringSync(jsonEncode({'url': url(), 'destPath': dest()}));

      expect(DownloadManager.instance.restoreQueue(tmp), 0);
      expect(meta.existsSync(), isFalse,
          reason: 'una ficha huérfana reaparecería en cada arranque');
    });

    test('lo que ya terminó no se vuelve a encolar', () {
      File(dest()).writeAsBytesSync(utf8.encode('A' * 2000));
      File('${dest()}.part').writeAsBytesSync(utf8.encode('A' * 500));
      File('${dest()}.part.meta').writeAsStringSync(
          jsonEncode({'url': url(), 'destPath': dest()}));

      expect(DownloadManager.instance.restoreQueue(tmp), 0);
    });

    test('una ficha ilegible no tumba el arranque', () {
      File('${dest()}.part').writeAsBytesSync(utf8.encode('A'));
      File('${dest()}.part.meta').writeAsStringSync('{no es json');

      expect(() => DownloadManager.instance.restoreQueue(tmp), returnsNormally);
    });
  });
}
