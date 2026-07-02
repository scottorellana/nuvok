// Pure-Dart reader for the ZIM file format (openzim.org), the container used
// by Kiwix for offline Wikipedia and friends. Cluster decompression is
// delegated to native zstd/lzma via FFI (see zim_native.dart).
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'zim_native.dart';

class ZimException implements Exception {
  ZimException(this.message);
  final String message;
  @override
  String toString() => 'ZimException: $message';
}

class ZimHeader {
  ZimHeader._({
    required this.majorVersion,
    required this.minorVersion,
    required this.uuid,
    required this.entryCount,
    required this.clusterCount,
    required this.urlPtrPos,
    required this.titlePtrPos,
    required this.clusterPtrPos,
    required this.mimeListPos,
    required this.mainPage,
    required this.checksumPos,
  });

  static const int magic = 0x044D495A;
  static const int noTitleIndex = 0xFFFFFFFFFFFFFFFF;
  static const int noMainPage = 0xFFFFFFFF;

  final int majorVersion;
  final int minorVersion;
  final String uuid;
  final int entryCount;
  final int clusterCount;
  final int urlPtrPos;
  final int titlePtrPos;
  final int clusterPtrPos;
  final int mimeListPos;
  final int mainPage;
  final int checksumPos;

  factory ZimHeader.parse(Uint8List bytes) {
    if (bytes.length < 80) throw ZimException('Cabecera truncada');
    final d = ByteData.sublistView(bytes);
    if (d.getUint32(0, Endian.little) != magic) {
      throw ZimException('No es un archivo ZIM (magic inválido)');
    }
    final uuidBytes = bytes.sublist(8, 24);
    return ZimHeader._(
      majorVersion: d.getUint16(4, Endian.little),
      minorVersion: d.getUint16(6, Endian.little),
      uuid: uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      entryCount: d.getUint32(24, Endian.little),
      clusterCount: d.getUint32(28, Endian.little),
      urlPtrPos: d.getUint64(32, Endian.little),
      titlePtrPos: d.getUint64(40, Endian.little),
      clusterPtrPos: d.getUint64(48, Endian.little),
      mimeListPos: d.getUint64(56, Endian.little),
      mainPage: d.getUint32(64, Endian.little),
      checksumPos: d.getUint64(72, Endian.little),
    );
  }
}

class ZimEntry {
  ZimEntry({
    required this.index,
    required this.namespace,
    required this.url,
    required this.title,
    required this.mimeTypeIndex,
    this.clusterNumber = -1,
    this.blobNumber = -1,
    this.redirectIndex = -1,
  });

  final int index;
  final String namespace;
  final String url;
  final String title;
  final int mimeTypeIndex;
  final int clusterNumber;
  final int blobNumber;
  final int redirectIndex;

  bool get isRedirect => mimeTypeIndex == 0xFFFF;
  String get fullPath => '$namespace/$url';
  String get displayTitle => title.isEmpty ? url : title;
}

class ZimBlob {
  ZimBlob(this.data, this.mimeType);
  final Uint8List data;
  final String mimeType;
}

class ZimSearchResult {
  ZimSearchResult(this.entry);
  final ZimEntry entry;
  String get title => entry.displayTitle;
  String get path => entry.fullPath;
}

class _DecompressedCluster {
  _DecompressedCluster(this.data, this.offsets);
  final Uint8List data;
  final List<int> offsets;
}

class ZimFile {
  ZimFile._(this.path, this._raf, this.header, this.mimeTypes);

  final String path;
  final RandomAccessFile _raf;
  final ZimHeader header;
  final List<String> mimeTypes;

  // LRU cache of decompressed clusters (a cluster is typically 0.5–2 MiB).
  final Map<int, _DecompressedCluster> _clusterCache = {};
  static const int _clusterCacheMax = 12;

  // Title-ordered article index (X/listing/titleOrdered/v1), loaded lazily.
  Uint8List? _titleIndexV1;
  bool _titleIndexLoaded = false;

  static Future<ZimFile> open(String filePath) async {
    final raf = await File(filePath).open();
    try {
      final headerBytes = await _readAt(raf, 0, 80);
      final header = ZimHeader.parse(headerBytes);
      // MIME list: zero-terminated strings, terminated by an empty string.
      final mimeRegionLen = header.urlPtrPos - header.mimeListPos;
      final mimeBytes = await _readAt(
          raf, header.mimeListPos, mimeRegionLen.clamp(0, 65536));
      final mimeTypes = <String>[];
      var start = 0;
      for (var i = 0; i < mimeBytes.length; i++) {
        if (mimeBytes[i] == 0) {
          if (i == start) break; // empty string → end of list
          mimeTypes.add(String.fromCharCodes(mimeBytes.sublist(start, i)));
          start = i + 1;
        }
      }
      return ZimFile._(filePath, raf, header, mimeTypes);
    } catch (_) {
      await raf.close();
      rethrow;
    }
  }

  Future<void> close() => _raf.close();

  static Future<Uint8List> _readAt(
      RandomAccessFile raf, int pos, int len) async {
    await raf.setPosition(pos);
    return raf.read(len);
  }

  Future<Uint8List> _read(int pos, int len) => _readAt(_raf, pos, len);

  // -- Entries ---------------------------------------------------------------

  Future<int> _urlPtr(int index) async {
    final b = await _read(header.urlPtrPos + index * 8, 8);
    return ByteData.sublistView(b).getUint64(0, Endian.little);
  }

  Future<ZimEntry> entryAt(int index) async {
    if (index < 0 || index >= header.entryCount) {
      throw ZimException('Índice de entrada fuera de rango: $index');
    }
    final direntPos = await _urlPtr(index);
    // Dirents are variable-length; read in growing chunks until both
    // zero-terminated strings (url, title) are present.
    var chunk = 384;
    while (true) {
      final bytes = await _read(direntPos, chunk);
      final entry = _parseDirent(index, bytes);
      if (entry != null) return entry;
      if (bytes.length < chunk) {
        throw ZimException('Dirent truncado en entrada $index');
      }
      chunk *= 2;
      if (chunk > 1 << 20) throw ZimException('Dirent inválido ($index)');
    }
  }

  ZimEntry? _parseDirent(int index, Uint8List bytes) {
    if (bytes.length < 12) return null;
    final d = ByteData.sublistView(bytes);
    final mimeIdx = d.getUint16(0, Endian.little);
    final namespace = String.fromCharCode(bytes[3]);
    final isRedirect = mimeIdx == 0xFFFF;
    var offset = 8; // mime(2) + paramLen(1) + namespace(1) + revision(4)
    var clusterNumber = -1, blobNumber = -1, redirectIndex = -1;
    if (isRedirect) {
      redirectIndex = d.getUint32(offset, Endian.little);
      offset += 4;
    } else {
      if (bytes.length < offset + 8) return null;
      clusterNumber = d.getUint32(offset, Endian.little);
      blobNumber = d.getUint32(offset + 4, Endian.little);
      offset += 8;
    }
    final url = _readCString(bytes, offset);
    if (url == null) return null;
    offset += url.$2 + 1;
    final title = _readCString(bytes, offset);
    if (title == null) return null;
    return ZimEntry(
      index: index,
      namespace: namespace,
      url: url.$1,
      title: title.$1,
      mimeTypeIndex: mimeIdx,
      clusterNumber: clusterNumber,
      blobNumber: blobNumber,
      redirectIndex: redirectIndex,
    );
  }

  (String, int)? _readCString(Uint8List bytes, int start) {
    for (var i = start; i < bytes.length; i++) {
      if (bytes[i] == 0) {
        return (
          utf8.decode(bytes.sublist(start, i), allowMalformed: true),
          i - start
        );
      }
    }
    return null;
  }

  /// Binary search over the URL pointer list (sorted by namespace + url).
  Future<ZimEntry?> entryByPath(String namespace, String url) async {
    var lo = 0, hi = header.entryCount - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final e = await entryAt(mid);
      final cmp = _comparePath(e.namespace, e.url, namespace, url);
      if (cmp == 0) return e;
      if (cmp < 0) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return null;
  }

  int _comparePath(String ns1, String url1, String ns2, String url2) {
    final nsCmp = ns1.compareTo(ns2);
    if (nsCmp != 0) return nsCmp;
    return _compareBytes(url1, url2);
  }

  int _compareBytes(String a, String b) {
    final ab = utf8.encode(a);
    final bb = utf8.encode(b);
    final n = ab.length < bb.length ? ab.length : bb.length;
    for (var i = 0; i < n; i++) {
      if (ab[i] != bb[i]) return ab[i] - bb[i];
    }
    return ab.length - bb.length;
  }

  Future<ZimEntry> resolveRedirect(ZimEntry entry, {int maxDepth = 8}) async {
    var current = entry;
    var depth = 0;
    while (current.isRedirect) {
      if (depth++ >= maxDepth) {
        throw ZimException('Cadena de redirecciones demasiado larga');
      }
      current = await entryAt(current.redirectIndex);
    }
    return current;
  }

  // -- Content ---------------------------------------------------------------

  Future<ZimBlob?> contentOf(ZimEntry entry) async {
    final resolved = await resolveRedirect(entry);
    if (resolved.clusterNumber < 0) return null;
    final cluster = await _cluster(resolved.clusterNumber);
    final b = resolved.blobNumber;
    if (b + 1 >= cluster.offsets.length) return null;
    final data = Uint8List.sublistView(
        cluster.data, cluster.offsets[b], cluster.offsets[b + 1]);
    final mime = resolved.mimeTypeIndex < mimeTypes.length
        ? mimeTypes[resolved.mimeTypeIndex]
        : 'application/octet-stream';
    return ZimBlob(Uint8List.fromList(data), mime);
  }

  Future<ZimBlob?> contentAtPath(String fullPath) async {
    final slash = fullPath.indexOf('/');
    if (slash != 1) return null;
    final entry =
        await entryByPath(fullPath[0], fullPath.substring(2));
    if (entry == null) return null;
    return contentOf(entry);
  }

  Future<int> _clusterPtr(int c) async {
    final b = await _read(header.clusterPtrPos + c * 8, 8);
    return ByteData.sublistView(b).getUint64(0, Endian.little);
  }

  Future<_DecompressedCluster> _cluster(int c) async {
    final cached = _clusterCache.remove(c);
    if (cached != null) {
      _clusterCache[c] = cached; // re-insert as most recently used
      return cached;
    }
    if (c < 0 || c >= header.clusterCount) {
      throw ZimException('Cluster fuera de rango: $c');
    }
    final start = await _clusterPtr(c);
    final end = c + 1 < header.clusterCount
        ? await _clusterPtr(c + 1)
        : header.checksumPos;
    final raw = await _read(start, end - start);
    if (raw.isEmpty) throw ZimException('Cluster $c vacío');
    final info = raw[0];
    final compression = info & 0x0F;
    final extended = (info & 0x10) != 0;
    final body = Uint8List.sublistView(raw, 1);
    final Uint8List data;
    switch (compression) {
      case 0:
      case 1:
        data = Uint8List.fromList(body);
        break;
      case 4:
        data = await Isolate.run(() => lzmaDecompress(body));
        break;
      case 5:
        data = await Isolate.run(() => zstdDecompress(body));
        break;
      default:
        throw ZimException('Compresión no soportada: $compression');
    }
    final offSize = extended ? 8 : 4;
    final d = ByteData.sublistView(data);
    int readOff(int i) => extended
        ? d.getUint64(i * 8, Endian.little)
        : d.getUint32(i * 4, Endian.little);
    final count = readOff(0) ~/ offSize;
    final offsets = List<int>.generate(count, readOff);
    final result = _DecompressedCluster(data, offsets);
    _clusterCache[c] = result;
    if (_clusterCache.length > _clusterCacheMax) {
      _clusterCache.remove(_clusterCache.keys.first);
    }
    return result;
  }

  // -- Well-known entries & metadata ------------------------------------------

  Future<ZimEntry?> mainPage() async {
    if (header.mainPage == ZimHeader.noMainPage) {
      final wk = await entryByPath('W', 'mainPage');
      return wk == null ? null : resolveRedirect(wk);
    }
    return resolveRedirect(await entryAt(header.mainPage));
  }

  Future<String?> metadata(String name) async {
    final e = await entryByPath('M', name);
    if (e == null) return null;
    final blob = await contentOf(e);
    if (blob == null) return null;
    return utf8.decode(blob.data, allowMalformed: true);
  }

  /// Illustration (cover icon) if present, e.g. 48x48 PNG.
  Future<Uint8List?> illustration() async {
    for (final name in ['Illustration_48x48@1', 'Favicon']) {
      final e = await entryByPath('M', name);
      if (e != null) {
        final blob = await contentOf(e);
        if (blob != null) return blob.data;
      }
    }
    return null;
  }

  // -- Title search ------------------------------------------------------------

  Future<Uint8List?> _titleIndex() async {
    if (_titleIndexLoaded) return _titleIndexV1;
    _titleIndexLoaded = true;
    final e = await entryByPath('X', 'listing/titleOrdered/v1');
    if (e != null) {
      final blob = await contentOf(e);
      _titleIndexV1 = blob?.data;
    }
    return _titleIndexV1;
  }

  int _titleIndexLength(Uint8List idx) => idx.length ~/ 4;

  int _titleIndexEntry(Uint8List idx, int pos) =>
      ByteData.sublistView(idx).getUint32(pos * 4, Endian.little);

  /// Prefix search over article titles. Case-insensitive first-letter helper:
  /// tries the query as-is and capitalized, merging results.
  Future<List<ZimSearchResult>> suggest(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];
    final variants = <String>{
      query,
      query[0].toUpperCase() + query.substring(1),
      query[0].toLowerCase() + query.substring(1),
    };
    final seen = <int>{};
    final results = <ZimSearchResult>[];
    for (final v in variants) {
      for (final r in await _suggestPrefix(v, limit)) {
        if (seen.add(r.entry.index)) results.add(r);
      }
      if (results.length >= limit) break;
    }
    return results.take(limit).toList();
  }

  Future<List<ZimSearchResult>> _suggestPrefix(String prefix, int limit) async {
    final idx = await _titleIndex();
    if (idx == null) return _suggestLinearScan(prefix, limit);
    final n = _titleIndexLength(idx);
    // lower_bound over title-ordered entries
    var lo = 0, hi = n;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      final e = await entryAt(_titleIndexEntry(idx, mid));
      if (_compareBytes(e.displayTitle, prefix) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final results = <ZimSearchResult>[];
    for (var i = lo; i < n && results.length < limit; i++) {
      final e = await entryAt(_titleIndexEntry(idx, i));
      if (!e.displayTitle.startsWith(prefix)) break;
      results.add(ZimSearchResult(await resolveRedirect(e)));
    }
    return results;
  }

  /// Fallback for ZIMs without a v1 title listing: scan C-namespace entries.
  /// Capped so a huge ZIM cannot freeze the UI.
  Future<List<ZimSearchResult>> _suggestLinearScan(
      String prefix, int limit) async {
    final results = <ZimSearchResult>[];
    final cap = header.entryCount < 50000 ? header.entryCount : 50000;
    final lower = prefix.toLowerCase();
    for (var i = 0; i < cap && results.length < limit; i++) {
      final e = await entryAt(i);
      if (e.namespace != 'C' && e.namespace != 'A') continue;
      if (e.displayTitle.toLowerCase().startsWith(lower)) {
        results.add(ZimSearchResult(await resolveRedirect(e)));
      }
    }
    return results;
  }
}
