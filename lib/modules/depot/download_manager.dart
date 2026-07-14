// Resumable download queue. Files are downloaded to "<name>.part" and only
// renamed to their final name once complete, so interrupted downloads can be
// resumed with an HTTP Range request and half-finished files never appear as
// usable content.
import 'dart:async';
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
  double? get progress =>
      totalBytes == null || totalBytes == 0 ? null : received / totalBytes!;
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

  void retry(DownloadTask task) {
    task.status = DownloadStatus.queued;
    task.error = null;
    notifyListeners();
    _pump();
  }

  void remove(DownloadTask task) {
    tasks.remove(task);
    try {
      if (task.partFile.existsSync() && task.status != DownloadStatus.done) {
        task.partFile.deleteSync();
      }
    } catch (_) {}
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

  Future<void> _download(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    task.error = null;
    notifyListeners();
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      var resumeFrom = 0;
      if (task.partFile.existsSync()) {
        resumeFrom = task.partFile.lengthSync();
      }
      final req = await client.getUrl(Uri.parse(task.url));
      req.followRedirects = true;
      req.maxRedirects = 8;
      if (resumeFrom > 0) {
        req.headers.add(HttpHeaders.rangeHeader, 'bytes=$resumeFrom-');
      }
      final res = await req.close();
      if (res.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        // Server says our .part is already the full file.
        await _finish(task);
        return;
      }
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final appending = res.statusCode == 206 && resumeFrom > 0;
      if (!appending) resumeFrom = 0;
      final contentLength =
          res.contentLength > 0 ? res.contentLength + resumeFrom : null;
      task.totalBytes = contentLength ?? task.totalBytes;
      task.received = resumeFrom;
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

  Future<void> _finish(DownloadTask task) async {
    // Verify integrity before exposing the file: a corrupt .gguf crashes the
    // native model load, so a bad download must never be renamed into place.
    if (task.sha256Hex != null) {
      final digest = await sha256.bind(task.partFile.openRead()).first;
      if (digest.toString() != task.sha256Hex) {
        try {
          task.partFile.deleteSync();
        } catch (_) {}
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
    task.status = DownloadStatus.done;
    task.received = File(task.destPath).lengthSync();
    task.totalBytes = task.received;
    notifyListeners();
  }
}
