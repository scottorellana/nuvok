// Resumable download queue. Files are downloaded to "<name>.part" and only
// renamed to their final name once complete, so interrupted downloads can be
// resumed with an HTTP Range request and half-finished files never appear as
// usable content.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

enum DownloadStatus { queued, downloading, paused, done, error }

class DownloadTask {
  DownloadTask({
    required this.url,
    required this.destPath,
    this.totalBytes,
    this.sha256Hex,
  });

  final String url;
  final String destPath;
  int? totalBytes;

  /// Expected content hash; verified before the final rename. null = skip.
  final String? sha256Hex;
  int received = 0;
  DownloadStatus status = DownloadStatus.queued;
  String? error;

  String get fileName => Uri.parse(destPath).pathSegments.last;
  File get partFile => File('$destPath.part');

  /// Ficha del trozo a medio bajar: qué URL era, y con qué validador
  /// (ETag / Last-Modified) lo dio el servidor.
  ///
  /// Sin esto, reanudar es a ciegas: si el archivo remoto cambió entre
  /// sesiones, el servidor manda los bytes de la versión NUEVA desde el
  /// offset viejo y quedan pegados a los de la anterior. Sale un archivo del
  /// tamaño correcto y contenido Frankenstein — un .gguf que carga y responde
  /// basura, o directamente revienta.
  File get metaFile => File('$destPath.part.meta');
  double? get progress =>
      totalBytes == null || totalBytes == 0 ? null : received / totalBytes!;
}

/// Lee el validador guardado junto al .part, o null si no hay ficha (o está
/// corrupta / es de otra URL: en ambos casos no sirve).
String? readPartValidator(DownloadTask task) {
  try {
    if (!task.metaFile.existsSync()) return null;
    final m = jsonDecode(task.metaFile.readAsStringSync()) as Map;
    if (m['url'] != task.url) return null;
    final v = m['validator'];
    return v is String && v.isNotEmpty ? v : null;
  } catch (_) {
    return null;
  }
}

void writePartValidator(DownloadTask task, String? validator) {
  try {
    task.metaFile.writeAsStringSync(jsonEncode({
      'url': task.url,
      'destPath': task.destPath,
      'validator': validator ?? '',
      'totalBytes': task.totalBytes,
      'sha256': task.sha256Hex,
    }));
  } catch (_) {
    // Sin ficha se pierde la reanudación segura, no la descarga.
  }
}

/// Total real del recurso que anuncia un 416 en "Content-Range: bytes * /N".
int? totalFromContentRange(String? header) {
  if (header == null) return null;
  final m = RegExp(r'/(\d+)\s*$').firstMatch(header.trim());
  return m == null ? null : int.tryParse(m.group(1)!);
}

class DownloadManager extends ChangeNotifier {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  final List<DownloadTask> tasks = [];
  bool _running = false;

  void enqueue(String url, String destPath,
      {int? totalBytes, String? sha256Hex}) {
    if (File(destPath).existsSync()) return; // already downloaded
    if (tasks.any(
        (t) => t.destPath == destPath && t.status != DownloadStatus.error)) {
      return; // already queued
    }
    tasks.add(DownloadTask(
        url: url,
        destPath: destPath,
        totalBytes: totalBytes,
        sha256Hex: sha256Hex));
    notifyListeners();
    _pump();
  }

  /// Reencola lo que quedó a medias en una sesión anterior.
  ///
  /// La cola vivía solo en memoria: cerrar la app (o que el sistema la mate,
  /// que es lo normal mientras bajan 2 GB con la pantalla apagada) la perdía
  /// entera. Los trozos seguían en disco ocupando gigabytes y nadie volvía a
  /// tocarlos; el usuario veía la descarga "sin empezar" y la relanzaba desde
  /// cero.
  ///
  /// La ficha de cada .part ya guarda url, destino, tamaño y hash: con eso se
  /// reconstruye la cola sin base de datos ni preferencias.
  int restoreQueue(Directory dir) {
    if (!dir.existsSync()) return 0;
    var restored = 0;
    for (final f in dir.listSync()) {
      if (f is! File || !f.path.endsWith('.part.meta')) continue;
      try {
        final m = jsonDecode(f.readAsStringSync()) as Map;
        final url = m['url'] as String?;
        final dest = m['destPath'] as String?;
        if (url == null || dest == null) continue;
        // El trozo se fue (limpieza del sistema, borrado manual): la ficha
        // sola no sirve para nada.
        if (!File('$dest.part').existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
          continue;
        }
        if (File(dest).existsSync()) continue; // ya terminó
        final sha = m['sha256'];
        enqueue(
          url,
          dest,
          totalBytes: (m['totalBytes'] as num?)?.toInt(),
          sha256Hex: sha is String && sha.isNotEmpty ? sha : null,
        );
        restored++;
      } catch (_) {
        // Ficha ilegible: no se puede reanudar a ciegas.
      }
    }
    return restored;
  }

  void retry(DownloadTask task) {
    task.status = DownloadStatus.queued;
    task.error = null;
    notifyListeners();
    _pump();
  }

  void remove(DownloadTask task) {
    tasks.remove(task);
    if (task.status != DownloadStatus.done) _discardPart(task);
    notifyListeners();
  }

  /// Returns the active (queued or downloading) task for [url], or null.
  DownloadTask? taskFor(String url) {
    for (final t in tasks) {
      if (t.url == url &&
          (t.status == DownloadStatus.queued ||
              t.status == DownloadStatus.downloading)) {
        return t;
      }
    }
    return null;
  }

  /// True if [url] is currently queued or downloading.
  bool isDownloading(String url) => taskFor(url) != null;

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        DownloadTask? next;
        for (final t in tasks) {
          if (t.status == DownloadStatus.queued) {
            next = t;
            break;
          }
        }
        if (next == null) break;
        await _download(next);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _download(DownloadTask task, {bool fresh = false}) async {
    task.status = DownloadStatus.downloading;
    task.error = null;
    notifyListeners();
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      var resumeFrom = 0;
      var validator = fresh ? null : readPartValidator(task);
      if (fresh) {
        _discardPart(task);
      } else if (task.partFile.existsSync()) {
        // Sin validador no hay forma de saber si el trozo corresponde a este
        // recurso. Se reanuda igual SOLO si hay hash esperado, porque
        // entonces un empalme de dos versiones se detecta al final y el
        // archivo no llega a instalarse. Sin hash y sin validador, tirar el
        // trozo es más barato que instalar un modelo corrupto.
        if (validator == null && task.sha256Hex == null) {
          _discardPart(task);
        } else {
          resumeFrom = task.partFile.lengthSync();
        }
      }
      final req = await client.getUrl(Uri.parse(task.url));
      req.followRedirects = true;
      req.maxRedirects = 8;
      if (resumeFrom > 0) {
        req.headers.add(HttpHeaders.rangeHeader, 'bytes=$resumeFrom-');
        // If-Range: si el recurso cambió, el servidor ignora el Range y manda
        // el archivo entero (RFC 9110 §13.1.5). Es lo que impide el empalme.
        if (validator != null) {
          req.headers.add('if-range', validator);
        }
      }
      final res = await req.close();
      if (res.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        final total =
            totalFromContentRange(res.headers.value(HttpHeaders.contentRangeHeader));
        if (total != null && resumeFrom == total) {
          // El trozo YA era el archivo completo: nada que bajar.
          await _finish(task);
          return;
        }
        // Nuestro offset no existe en el recurso: el .part no corresponde a
        // este archivo (corrupto, sobrante, o de una versión más grande). No
        // vale ni un byte. Antes esto se daba por descarga terminada y
        // renombraba basura a definitivo.
        _discardPart(task);
        if (!fresh) {
          await _download(task, fresh: true);
          return;
        }
        throw const HttpException('El servidor rechazó la reanudación');
      }
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final appending = res.statusCode == 206 && resumeFrom > 0;
      if (!appending) {
        resumeFrom = 0;
        // 200 tras pedir Range = el recurso cambió y el servidor mandó el
        // archivo entero: lo que había no sirve.
        if (task.partFile.existsSync()) _discardPart(task);
      }
      // Guardar el validador de ESTA respuesta para la próxima reanudación.
      validator = res.headers.value(HttpHeaders.etagHeader) ??
          res.headers.value(HttpHeaders.lastModifiedHeader);
      final contentLength =
          res.contentLength > 0 ? res.contentLength + resumeFrom : null;
      task.totalBytes = contentLength ?? task.totalBytes;
      task.received = resumeFrom;
      writePartValidator(task, validator);
      final sink = task.partFile
          .openWrite(mode: appending ? FileMode.append : FileMode.write);
      var lastNotify = DateTime.now();
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          task.received += chunk.length;
          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds > 300) {
            lastNotify = now;
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
      if (task.totalBytes != null &&
          task.partFile.lengthSync() < task.totalBytes!) {
        throw const HttpException('Descarga incompleta (conexión perdida)');
      }
      await _finish(task);
    } on SocketException {
      task.status = DownloadStatus.error;
      task.error = 'Sin conexión — la descarga se reanudará donde quedó';
      notifyListeners();
    } on FileSystemException catch (e) {
      task.status = DownloadStatus.error;
      task.error = 'Error de archivo: ${e.message}';
      notifyListeners();
    } catch (e) {
      task.status = DownloadStatus.error;
      task.error = e.toString();
      notifyListeners();
    } finally {
      client.close();
    }
  }

  /// Tira el trozo a medio bajar y su ficha. Se llama cuando hay motivo para
  /// creer que NO corresponde al recurso: reanudar sobre él produciría un
  /// archivo empalmado de dos versiones.
  void _discardPart(DownloadTask task) {
    for (final f in [task.partFile, task.metaFile]) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    task.received = 0;
  }

  Future<void> _finish(DownloadTask task) async {
    // Verify integrity before exposing the file: a corrupt .gguf crashes the
    // native model load, so a bad download must never be renamed into place.
    if (task.sha256Hex != null) {
      final digest = await sha256.bind(task.partFile.openRead()).first;
      if (digest.toString() != task.sha256Hex) {
        _discardPart(task);
        task.status = DownloadStatus.error;
        task.error = 'Verificación fallida: el archivo llegó corrupto';
        notifyListeners();
        return;
      }
    }
    // Ensure the destination directory exists (it may have been deleted).
    final slash = task.destPath.lastIndexOf('/');
    if (slash > 0) {
      await Directory(task.destPath.substring(0, slash)).create(recursive: true);
    }
    await task.partFile.rename(task.destPath);
    try {
      if (task.metaFile.existsSync()) task.metaFile.deleteSync();
    } catch (_) {}
    task.status = DownloadStatus.done;
    task.received = File(task.destPath).lengthSync();
    task.totalBytes = task.received;
    notifyListeners();
  }
}
