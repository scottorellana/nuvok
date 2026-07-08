// Pure-Dart PMTiles v3 extract: cuts a bbox region out of a (possibly
// remote) planet file using range requests — the same operation as
// `pmtiles extract`, but running on the phone itself. This is what lets a
// production iPhone/Android download any country map straight from the
// public Protomaps daily builds, with zero servers of our own.
//
// Spec: https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pmtiles/pmtiles.dart' show ZXY;

// ─────────────────────────────────────────────────────────────────────────
// Tile coordinate helpers
// ─────────────────────────────────────────────────────────────────────────

/// Hilbert tile id for (z,x,y) — delegates to the pmtiles package so our
/// writer and its reader can never disagree.
int zxyToTileId(int z, int x, int y) => ZXY(z, x, y).toTileId();

int lonToTileX(double lon, int z) =>
    ((lon + 180.0) / 360.0 * (1 << z)).floor().clamp(0, (1 << z) - 1);

int latToTileY(double lat, int z) {
  final latRad = lat * pi / 180.0;
  final n = 1 << z;
  final y = ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * n)
      .floor();
  return y.clamp(0, n - 1);
}

// ─────────────────────────────────────────────────────────────────────────
// Header / directory (de)serialization
// ─────────────────────────────────────────────────────────────────────────

class PmHeaderInfo {
  PmHeaderInfo(this._b) {
    if (String.fromCharCodes(_b.sublist(0, 7)) != 'PMTiles' || _b[7] != 3) {
      throw const FormatException('No es un archivo PMTiles v3');
    }
  }
  final Uint8List _b;

  int _u64(int o) => ByteData.sublistView(_b).getUint64(o, Endian.little);

  int get rootOffset => _u64(8);
  int get rootLength => _u64(16);
  int get metadataOffset => _u64(24);
  int get metadataLength => _u64(32);
  int get leafOffset => _u64(40);
  int get leafLength => _u64(48);
  int get dataOffset => _u64(56);
  int get dataLength => _u64(64);
  int get internalCompression => _b[97]; // 1 none, 2 gzip
  int get tileCompression => _b[98];
  int get tileType => _b[99];
  int get minZoom => _b[100];
  int get maxZoom => _b[101];
}

class PmEntry {
  PmEntry({
    required this.tileId,
    required this.offset,
    required this.length,
    required this.runLength,
  });
  final int tileId;
  int offset;
  final int length;
  int runLength;
}

class _VarintReader {
  _VarintReader(this.bytes);
  final Uint8List bytes;
  int pos = 0;
  int read() {
    var value = 0, shift = 0;
    while (true) {
      final b = bytes[pos++];
      value |= (b & 0x7f) << shift;
      if (b < 0x80) return value;
      shift += 7;
    }
  }
}

void _writeVarint(BytesBuilder out, int value) {
  var v = value;
  while (v >= 0x80) {
    out.addByte((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.addByte(v);
}

List<PmEntry> deserializeDirectory(Uint8List uncompressed) {
  final r = _VarintReader(uncompressed);
  final n = r.read();
  final entries = <PmEntry>[];
  var lastId = 0;
  for (var i = 0; i < n; i++) {
    lastId += r.read();
    entries.add(PmEntry(tileId: lastId, offset: 0, length: 0, runLength: 0));
  }
  for (var i = 0; i < n; i++) {
    entries[i].runLength = r.read();
  }
  final lengths = List<int>.generate(n, (_) => r.read());
  for (var i = 0; i < n; i++) {
    final v = r.read();
    if (v == 0 && i > 0) {
      entries[i].offset = entries[i - 1].offset + lengths[i - 1];
    } else {
      entries[i].offset = v - 1;
    }
  }
  for (var i = 0; i < n; i++) {
    entries[i] = PmEntry(
        tileId: entries[i].tileId,
        offset: entries[i].offset,
        length: lengths[i],
        runLength: entries[i].runLength);
  }
  return entries;
}

Uint8List serializeDirectory(List<PmEntry> entries) {
  final out = BytesBuilder();
  _writeVarint(out, entries.length);
  var last = 0;
  for (final e in entries) {
    _writeVarint(out, e.tileId - last);
    last = e.tileId;
  }
  for (final e in entries) {
    _writeVarint(out, e.runLength);
  }
  for (final e in entries) {
    _writeVarint(out, e.length);
  }
  for (var i = 0; i < entries.length; i++) {
    if (i > 0 &&
        entries[i].offset == entries[i - 1].offset + entries[i - 1].length) {
      _writeVarint(out, 0);
    } else {
      _writeVarint(out, entries[i].offset + 1);
    }
  }
  return out.toBytes();
}

Uint8List _decompress(Uint8List data, int compression) {
  switch (compression) {
    case 1:
      return data;
    case 2:
      return Uint8List.fromList(gzip.decode(data));
    default:
      throw FormatException('Compresión interna no soportada: $compression');
  }
}

Uint8List _gzipBytes(List<int> data) => Uint8List.fromList(gzip.encode(data));

// ─────────────────────────────────────────────────────────────────────────
// Range sources: local file or HTTP with Range requests (+retry)
// ─────────────────────────────────────────────────────────────────────────

abstract class RangeSource {
  Future<Uint8List> read(int offset, int length);
  Future<void> close();
}

class FileRangeSource implements RangeSource {
  FileRangeSource(File f) : _raf = f.openSync();
  final RandomAccessFile _raf;

  @override
  Future<Uint8List> read(int offset, int length) async {
    _raf.setPositionSync(offset);
    return _raf.readSync(length);
  }

  @override
  Future<void> close() async => _raf.closeSync();
}

class HttpRangeSource implements RangeSource {
  HttpRangeSource(this.url)
      : _client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 20);
  final Uri url;
  final HttpClient _client;

  @override
  Future<Uint8List> read(int offset, int length) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final req = await _client.getUrl(url);
        req.headers
            .set(HttpHeaders.rangeHeader, 'bytes=$offset-${offset + length - 1}');
        final res = await req.close();
        if (res.statusCode != 206 && res.statusCode != 200) {
          throw HttpException('HTTP ${res.statusCode}', uri: url);
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in res) {
          builder.add(chunk);
        }
        final bytes = builder.toBytes();
        if (bytes.length < length && res.statusCode == 206) {
          throw HttpException('rango incompleto (${bytes.length}/$length)');
        }
        return bytes.length > length ? bytes.sublist(0, length) : bytes;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
    throw Exception('Descarga falló tras 3 intentos: $lastError');
  }

  @override
  Future<void> close() async => _client.close(force: true);
}

// ─────────────────────────────────────────────────────────────────────────
// Writer
// ─────────────────────────────────────────────────────────────────────────

/// Writes a valid PMTiles v3 file. [entries] sorted by tileId with offsets
/// into the logical data section formed by concatenating [dataBlobs].
Future<void> writePmTiles({
  required File dest,
  required List<PmEntry> entries,
  required List<Uint8List> dataBlobs,
  required String metadataJson,
  required int minZoom,
  required int maxZoom,
  required int tileType,
  required int tileCompression,
  required List<int> boundsE7, // [minLonE7, minLatE7, maxLonE7, maxLatE7]
  bool clustered = true,
}) async {
  const maxRootEntries = 16384;
  Uint8List rootBytes;
  Uint8List leavesBytes = Uint8List(0);
  if (entries.length <= maxRootEntries) {
    rootBytes = _gzipBytes(serializeDirectory(entries));
  } else {
    // Split into leaf directories; the root only points at them.
    const leafSize = 12288;
    final root = <PmEntry>[];
    final leaves = BytesBuilder();
    for (var i = 0; i < entries.length; i += leafSize) {
      final chunk = entries.sublist(i, min(i + leafSize, entries.length));
      final leaf = _gzipBytes(serializeDirectory(chunk));
      root.add(PmEntry(
          tileId: chunk.first.tileId,
          offset: leaves.length,
          length: leaf.length,
          runLength: 0));
      leaves.add(leaf);
    }
    rootBytes = _gzipBytes(serializeDirectory(root));
    leavesBytes = leaves.toBytes();
  }
  final metaBytes = _gzipBytes(metadataJson.codeUnits);

  final rootOffset = 127;
  final metaOffset = rootOffset + rootBytes.length;
  final leafOffset = metaOffset + metaBytes.length;
  final dataOffset = leafOffset + leavesBytes.length;
  final dataLength = dataBlobs.fold<int>(0, (s, b) => s + b.length);

  final addressedTiles =
      entries.fold<int>(0, (s, e) => s + max(1, e.runLength));

  final header = Uint8List(127);
  header.setRange(0, 7, 'PMTiles'.codeUnits);
  header[7] = 3;
  final bd = ByteData.sublistView(header);
  bd.setUint64(8, rootOffset, Endian.little);
  bd.setUint64(16, rootBytes.length, Endian.little);
  bd.setUint64(24, metaOffset, Endian.little);
  bd.setUint64(32, metaBytes.length, Endian.little);
  bd.setUint64(40, leafOffset, Endian.little);
  bd.setUint64(48, leavesBytes.length, Endian.little);
  bd.setUint64(56, dataOffset, Endian.little);
  bd.setUint64(64, dataLength, Endian.little);
  bd.setUint64(72, addressedTiles, Endian.little); // addressed tiles
  bd.setUint64(80, entries.length, Endian.little); // tile entries
  bd.setUint64(88, dataBlobs.length, Endian.little); // tile contents
  header[96] = clustered ? 1 : 0;
  header[97] = 2; // internal compression: gzip
  header[98] = tileCompression;
  header[99] = tileType;
  header[100] = minZoom;
  header[101] = maxZoom;
  bd.setInt32(102, boundsE7[0], Endian.little);
  bd.setInt32(106, boundsE7[1], Endian.little);
  bd.setInt32(110, boundsE7[2], Endian.little);
  bd.setInt32(114, boundsE7[3], Endian.little);
  header[118] = min(maxZoom, 7); // center zoom
  bd.setInt32(119, (boundsE7[0] + boundsE7[2]) ~/ 2, Endian.little);
  bd.setInt32(123, (boundsE7[1] + boundsE7[3]) ~/ 2, Endian.little);

  final sink = dest.openWrite();
  sink.add(header);
  sink.add(rootBytes);
  sink.add(metaBytes);
  sink.add(leavesBytes);
  for (final b in dataBlobs) {
    sink.add(b);
  }
  await sink.close();
}

// ─────────────────────────────────────────────────────────────────────────
// Extract
// ─────────────────────────────────────────────────────────────────────────

/// Cuts the [west]/[south]/[east]/[north] bbox (up to [maxZoom]) out of
/// [source] into [dest]. Emits human-readable progress via [onProgress].
Future<void> extractPmTiles({
  required RangeSource source,
  required File dest,
  required double west,
  required double south,
  required double east,
  required double north,
  int? maxZoom,
  void Function(String message, double? fraction)? onProgress,
}) async {
  void progress(String m, [double? f]) => onProgress?.call(m, f);

  try {
    progress('Leyendo índice del mapa mundial…');
    final header = PmHeaderInfo(await source.read(0, 127));
    final zLimit = min(maxZoom ?? header.maxZoom, header.maxZoom);

    // Every tileId inside the bbox for each zoom, sorted. Sizes are modest:
    // a country at z15 is a few hundred thousand ids.
    final wanted = <int>[];
    for (var z = header.minZoom; z <= zLimit; z++) {
      final x0 = lonToTileX(west, z), x1 = lonToTileX(east, z);
      final y0 = latToTileY(north, z), y1 = latToTileY(south, z);
      for (var x = x0; x <= x1; x++) {
        for (var y = y0; y <= y1; y++) {
          wanted.add(zxyToTileId(z, x, y));
        }
      }
    }
    wanted.sort();
    final wantedSet = wanted.toSet();
    if (wanted.isEmpty) {
      throw const FormatException('El área pedida no contiene tiles');
    }

    bool rangeHasWanted(int startId, int endId) {
      // Binary search: any wanted id in [startId, endId)?
      var lo = 0, hi = wanted.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (wanted[mid] < startId) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      return lo < wanted.length && wanted[lo] < endId;
    }

    // Walk root (and relevant leaves) collecting the entries we keep.
    final rootRaw = await source.read(header.rootOffset, header.rootLength);
    final root =
        deserializeDirectory(_decompress(rootRaw, header.internalCompression));

    final selected = <PmEntry>[]; // tileId → src offset/length (run expanded)
    void selectFrom(List<PmEntry> dir) {
      for (final e in dir) {
        if (e.runLength == 0) continue; // leaf pointer, handled by caller
        for (var k = 0; k < e.runLength; k++) {
          final id = e.tileId + k;
          if (wantedSet.contains(id)) {
            selected.add(PmEntry(
                tileId: id, offset: e.offset, length: e.length, runLength: 1));
          }
        }
      }
    }

    selectFrom(root);
    final leafPointers = [
      for (var i = 0; i < root.length; i++)
        if (root[i].runLength == 0) (i, root[i])
    ];
    var leafsRead = 0;
    for (final (i, leaf) in leafPointers) {
      final endId = i + 1 < root.length
          ? root[i + 1].tileId
          : zxyToTileId(zLimit, (1 << zLimit) - 1, (1 << zLimit) - 1) + 1;
      if (!rangeHasWanted(leaf.tileId, endId)) continue;
      final raw =
          await source.read(header.leafOffset + leaf.offset, leaf.length);
      selectFrom(
          deserializeDirectory(_decompress(raw, header.internalCompression)));
      leafsRead++;
      progress('Índice: ${++leafsRead > 0 ? leafsRead : 0} bloques…');
    }
    selected.sort((a, b) => a.tileId.compareTo(b.tileId));
    if (selected.isEmpty) {
      throw const FormatException(
          'La región no tiene datos en este mapa (¿bbox fuera de cobertura?)');
    }

    // Dedup blobs (shared ocean tiles etc.) and merge byte ranges so the
    // whole download happens in a handful of big requests.
    final blobKey = <String, int>{}; // "off:len" → blob index
    final blobs = <(int, int)>[]; // src offset,length per unique blob
    final entryBlob = List<int>.filled(selected.length, 0);
    for (var i = 0; i < selected.length; i++) {
      final e = selected[i];
      final key = '${e.offset}:${e.length}';
      entryBlob[i] = blobKey.putIfAbsent(key, () {
        blobs.add((e.offset, e.length));
        return blobs.length - 1;
      });
    }

    final order = List<int>.generate(blobs.length, (i) => i)
      ..sort((a, b) => blobs[a].$1.compareTo(blobs[b].$1));
    const mergeGap = 512 * 1024;
    final ranges = <(int, int, List<int>)>[]; // start, end, blob indexes
    for (final bi in order) {
      final (off, len) = blobs[bi];
      if (ranges.isNotEmpty && off <= ranges.last.$2 + mergeGap) {
        final last = ranges.removeLast();
        ranges.add((last.$1, max(last.$2, off + len), [...last.$3, bi]));
      } else {
        ranges.add((off, off + len, [bi]));
      }
    }
    final totalBytes = ranges.fold<int>(0, (s, r) => s + (r.$2 - r.$1));
    progress(
        'Descargando ${selected.length} tiles '
        '(${(totalBytes / 1048576).toStringAsFixed(1)} MB)…',
        0);

    // Download ranges → temp file keyed by blob (source order maximizes
    // range merging); final data gets rewritten in tileId order below.
    final tmpData = File('${dest.path}.data');
    final dataSink = tmpData.openSync(mode: FileMode.write);
    final tmpOffset = List<int>.filled(blobs.length, 0);
    var tmpWritten = 0, done = 0;
    try {
      for (final (start, end, members) in ranges) {
        final chunk = await source.read(header.dataOffset + start, end - start);
        for (final bi in members) {
          final (off, len) = blobs[bi];
          tmpOffset[bi] = tmpWritten;
          dataSink.writeFromSync(chunk, off - start, off - start + len);
          tmpWritten += len;
        }
        done += end - start;
        progress(
            'Descargando… ${(done / 1048576).toStringAsFixed(1)} / '
            '${(totalBytes / 1048576).toStringAsFixed(1)} MB',
            done / totalBytes);
      }
    } finally {
      dataSink.closeSync();
    }

    // Assign final offsets in tileId order (first appearance): that makes
    // the archive CLUSTERED, which the app's own pmtiles reader requires.
    final newOffset = List<int>.filled(blobs.length, -1);
    var written = 0;
    for (var i = 0; i < selected.length; i++) {
      final bi = entryBlob[i];
      if (newOffset[bi] == -1) {
        newOffset[bi] = written;
        written += blobs[bi].$2;
      }
    }

    // Rebuild entries against new offsets, re-forming runs where possible.
    final outEntries = <PmEntry>[];
    for (var i = 0; i < selected.length; i++) {
      final e = selected[i];
      final off = newOffset[entryBlob[i]];
      final prev = outEntries.isEmpty ? null : outEntries.last;
      if (prev != null &&
          prev.tileId + prev.runLength == e.tileId &&
          prev.offset == off &&
          prev.length == e.length) {
        prev.runLength++; // shared blob, consecutive ids → keep it a run
      } else {
        outEntries.add(PmEntry(
            tileId: e.tileId, offset: off, length: e.length, runLength: 1));
      }
    }

    progress('Escribiendo mapa…');
    final metaRaw =
        await source.read(header.metadataOffset, header.metadataLength);
    final metaJson = String.fromCharCodes(
        _decompress(metaRaw, header.internalCompression));

    // Assemble final file: header+dirs+meta then the data file contents.
    final assembled = File('${dest.path}.part');
    await writePmTiles(
      dest: assembled,
      entries: outEntries,
      dataBlobs: const [],
      metadataJson: metaJson,
      minZoom: header.minZoom,
      maxZoom: zLimit,
      tileType: header.tileType,
      tileCompression: header.tileCompression,
      boundsE7: [
        (west * 1e7).round(),
        (south * 1e7).round(),
        (east * 1e7).round(),
        (north * 1e7).round(),
      ],
    );
    // writePmTiles wrote everything except data (empty blobs); append each
    // unique blob in tileId order (clustered layout), reading from the temp.
    final raf = assembled.openSync(mode: FileMode.append);
    final dataRaf = tmpData.openSync();
    try {
      final emitted = List<bool>.filled(blobs.length, false);
      for (var i = 0; i < selected.length; i++) {
        final bi = entryBlob[i];
        if (emitted[bi]) continue;
        emitted[bi] = true;
        dataRaf.setPositionSync(tmpOffset[bi]);
        raf.writeFromSync(dataRaf.readSync(blobs[bi].$2));
      }
    } finally {
      raf.closeSync();
      dataRaf.closeSync();
      tmpData.deleteSync();
    }
    // Patch data length (writePmTiles computed 0 for empty blob list).
    final patch = assembled.openSync(mode: FileMode.append);
    try {
      patch.setPositionSync(64);
      final b = ByteData(8)..setUint64(0, written, Endian.little);
      patch.writeFromSync(b.buffer.asUint8List());
      patch.setPositionSync(88);
      final c = ByteData(8)..setUint64(0, blobs.length, Endian.little);
      patch.writeFromSync(c.buffer.asUint8List());
    } finally {
      patch.closeSync();
    }
    if (dest.existsSync()) dest.deleteSync();
    assembled.renameSync(dest.path);
    progress('listo', 1);
  } finally {
    await source.close();
  }
}
