// The in-app map installer's region catalog plus the machinery to get a
// region installed: direct download when a URL exists, or a pure-Dart
// `pmtiles extract` against the Protomaps daily build — runs on EVERY
// platform (iPhone/Android/desktop), so production users download any
// country map straight from the app with zero servers of ours.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/prepper_library.dart';
import 'pmtiles_extract_dart.dart';

class MapRegion {
  MapRegion({
    required this.id,
    required this.name,
    required this.flag,
    required this.sizeMB,
    this.group = 'Otros',
    this.bbox,
    this.url,
    this.maxZoom,
  });

  final String id;
  final String name;
  final String flag;
  final String group; // continent/region for grouping in the UI
  final int sizeMB;
  final String? bbox; // minLon,minLat,maxLon,maxLat
  final String? url; // direct .pmtiles download when hosted somewhere
  final int? maxZoom; // cap zoom for large regions so they stay downloadable

  String get fileName => '$id.pmtiles';

  bool get installed =>
      File('${PrepperLibrary.instance.mapsDir.path}/$fileName').existsSync();
}

class MapCatalog {
  static List<MapRegion>? _cached;

  static Future<List<MapRegion>> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString('assets/map_catalog.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _cached = [
      for (final r in (json['regions'] as List).cast<Map<String, dynamic>>())
        MapRegion(
          id: r['id'] as String,
          name: r['name'] as String,
          flag: r['flag'] as String? ?? '🗺️',
          group: r['group'] as String? ?? 'Otros',
          sizeMB: (r['sizeMB'] as num?)?.toInt() ?? 0,
          bbox: r['bbox'] as String?,
          url: r['url'] as String?,
          maxZoom: (r['maxZoom'] as num?)?.toInt(),
        ),
    ];
    return _cached!;
  }
}

/// Runs `pmtiles extract` for one region against the latest Protomaps daily
/// build. Desktop-only (needs the CLI binary); progress lines stream out so
/// the UI can show something alive during the minutes it takes.
class MapExtractor {
  /// Pure-Dart extract works everywhere; only a bbox is required.
  static bool get available => true;

  static const _buildHost = 'https://build.protomaps.com';

  /// Most recent daily build file name (e.g. 20260703.pmtiles), probed by
  /// date walking back from today. Cheap: one 1-byte range request per try.
  static Future<String?> latestBuild() async {
    final now = DateTime.now().toUtc();
    for (var back = 0; back < 10; back++) {
      final d = now.subtract(Duration(days: back));
      final name = '${d.year.toString().padLeft(4, '0')}'
          '${d.month.toString().padLeft(2, '0')}'
          '${d.day.toString().padLeft(2, '0')}.pmtiles';
      if (await _buildExists(name)) return name;
    }
    return null;
  }

  static Future<bool> _buildExists(String name) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final req = await client.getUrl(Uri.parse('$_buildHost/$name'));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode == 206 || res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client?.close();
    }
  }

  /// Extracts [region] into the maps folder using the pure-Dart engine.
  /// Emits progress lines; writes to a temp path and renames only on
  /// success, so a killed extract never leaves a half map behind.
  static Stream<String> extract(MapRegion region) async* {
    final bbox = region.bbox;
    if (bbox == null) {
      yield 'error: esta región no tiene área definida';
      return;
    }
    final parts = bbox.split(',').map(double.parse).toList();
    if (parts.length != 4) {
      yield 'error: bbox inválido';
      return;
    }
    yield 'Buscando el mapa mundial más reciente…';
    final build = await latestBuild();
    if (build == null) {
      yield 'error: no hay conexión a build.protomaps.com. Revisa tu '
          'internet (si funciona, quizá el firewall bloquea la descarga). '
          'Como alternativa usa "Por URL" o "Importar archivo".';
      return;
    }
    final dest = '${PrepperLibrary.instance.mapsDir.path}/${region.fileName}';
    yield 'Extrayendo ${region.name} del mapa mundial ($build)…';

    final progress = StreamController<String>();
    final done = extractPmTiles(
      source: HttpRangeSource(Uri.parse('$_buildHost/$build')),
      dest: File(dest),
      west: parts[0],
      south: parts[1],
      east: parts[2],
      north: parts[3],
      maxZoom: region.maxZoom,
      onProgress: (m, f) {
        if (!progress.isClosed) progress.add(m);
      },
    ).then((_) {
      if (!progress.isClosed) progress.close();
    }).catchError((Object e) {
      if (!progress.isClosed) {
        progress.add('error: $e');
        progress.close();
      }
    });

    yield* progress.stream;
    await done;
    if (File(dest).existsSync()) {
      yield 'listo: ${region.name} instalado';
    }
  }
}

