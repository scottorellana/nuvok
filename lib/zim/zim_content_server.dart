// Internal loopback content server: serves ZIM entries to the in-app
// WebView over 127.0.0.1 on an ephemeral port — an invisible implementation
// detail, the same pattern the AI module uses for llama-server. Supports
// HTTP Range requests so large videos stream from disk instead of loading
// into memory.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'zim_file.dart';

class ZimContentServer {
  ZimContentServer._();
  static final ZimContentServer instance = ZimContentServer._();

  HttpServer? _server;
  final Map<String, ZimFile> _zims = {};

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (_) {});
  }

  /// Registers a ZIM and returns the URL of its main page.
  Future<Uri?> serve(ZimFile zim) async {
    await _ensureStarted();
    final id = _idFor(zim.path);
    _zims[id] = zim;
    final main = await zim.mainPage();
    if (main == null) return null;
    return urlFor(zim, main.fullPath);
  }

  Uri urlFor(ZimFile zim, String zimPath) {
    final id = _idFor(zim.path);
    final encoded = zimPath.split('/').map(Uri.encodeComponent).join('/');
    return Uri.parse('http://127.0.0.1:${_server!.port}/z/$id/$encoded');
  }

  void release(ZimFile zim) {
    _zims.remove(_idFor(zim.path));
  }

  String _idFor(String path) => path.hashCode.toUnsigned(32).toRadixString(16);

  Future<void> _handle(HttpRequest req) async {
    try {
      final segments = req.uri.pathSegments;
      if (segments.length < 3 || segments[0] != 'z') {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      final zim = _zims[segments[1]];
      if (zim == null) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      final zimPath = segments.sublist(2).map(Uri.decodeComponent).join('/');
      await _serveEntry(req, zim, zimPath);
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveEntry(HttpRequest req, ZimFile zim, String zimPath) async {
    final slash = zimPath.indexOf('/');
    final res = req.response;
    if (slash != 1) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    var entry = await zim.entryByPath(zimPath[0], zimPath.substring(2));
    if (entry == null) {
      res.statusCode = HttpStatus.notFound;
      res.headers.contentType = ContentType.html;
      res.write('<h1>No encontrado</h1><p>${htmlEscape.convert(zimPath)}</p>');
      await res.close();
      return;
    }
    // ZIM redirect → HTTP redirect so relative links resolve correctly.
    if (entry.isRedirect) {
      final target = await zim.resolveRedirect(entry);
      res.statusCode = HttpStatus.movedTemporarily;
      res.headers
          .set(HttpHeaders.locationHeader, urlFor(zim, target.fullPath).path);
      await res.close();
      return;
    }

    // Media in uncompressed clusters: stream ranges straight from disk.
    final location = await zim.blobLocation(entry);
    if (location != null) {
      await _streamRange(req, zim, location);
      return;
    }

    // Compressed content (HTML, CSS, images): serve the whole blob.
    final blob = await zim.contentOf(entry);
    if (blob == null) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    res.headers.contentType = ContentType.parse(_normalizeMime(blob.mimeType));
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    res.contentLength = blob.data.length;
    res.add(blob.data);
    await res.close();
  }

  Future<void> _streamRange(
    HttpRequest req,
    ZimFile zim,
    ({int offset, int length, String mimeType}) loc,
  ) async {
    final res = req.response;
    var start = 0;
    var end = loc.length - 1;
    final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
    final isRange = rangeHeader != null && rangeHeader.startsWith('bytes=');
    if (isRange) {
      final parts = rangeHeader.substring(6).split('-');
      start = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1 && parts[1].isNotEmpty) {
        end = int.tryParse(parts[1]) ?? end;
      }
      if (start > end || start >= loc.length) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers
            .set(HttpHeaders.contentRangeHeader, 'bytes */${loc.length}');
        await res.close();
        return;
      }
      if (end >= loc.length) end = loc.length - 1;
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(
          HttpHeaders.contentRangeHeader, 'bytes $start-$end/${loc.length}');
    }
    res.headers.contentType = ContentType.parse(_normalizeMime(loc.mimeType));
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    final total = end - start + 1;
    res.contentLength = total;
    // Stream in chunks so a 300MB video never sits in RAM.
    const chunk = 1 << 20;
    var sent = 0;
    while (sent < total) {
      final n = (total - sent) < chunk ? (total - sent) : chunk;
      final bytes = await zim.readRange(loc.offset + start + sent, n);
      if (bytes.isEmpty) break;
      res.add(bytes);
      sent += bytes.length;
    }
    await res.close();
  }

  String _normalizeMime(String mime) {
    final m = mime.split(';').first.trim();
    return m.isEmpty ? 'application/octet-stream' : m;
  }
}
