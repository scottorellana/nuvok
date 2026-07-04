// The in-app map installer's region catalog plus the machinery to get a
// region installed: direct download when a URL exists, or a real
// `pmtiles extract` against the Protomaps daily build when the CLI binary is
// available (desktop) — the same process that produced the original Honduras
// map, now one tap instead of a terminal session.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/prepper_library.dart';

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
  /// Where the pmtiles CLI may live. First hit wins.
  static final List<String> _binCandidates = [
    '${Platform.environment['HOME'] ?? ''}/development/bin/pmtiles',
    '/usr/local/bin/pmtiles',
    '/opt/homebrew/bin/pmtiles',
  ];

  static String? binaryPath() {
    if (Platform.isAndroid || Platform.isIOS) return null;
    for (final p in _binCandidates) {
      if (p.isNotEmpty && File(p).existsSync()) return p;
    }
    return null;
  }

  static bool get available => binaryPath() != null;

  static const _buildHost = 'https://build.protomaps.com';

  /// Most recent daily build file name (e.g. 20260703.pmtiles). Protomaps
  /// no longer publishes a builds.json index, so we probe by date: today's
  /// build, then walk back day by day until one answers. A HEAD-style range
  /// request (first byte only) is enough to know a build exists.
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
      // Ask for just the first byte: cheap existence check with no download.
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final res = await req.close();
      await res.drain<void>();
      // 206 = range served (exists); 200 = full (exists); 404 = missing.
      return res.statusCode == 206 || res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client?.close();
    }
  }

  /// Extracts [region] into the maps folder. Emits progress lines. The
  /// output goes to a .part path and is renamed only on success, so a killed
  /// extract can never leave a half map that the Maps module would open.
  static Stream<String> extract(MapRegion region) async* {
    final bin = binaryPath();
    final bbox = region.bbox;
    if (bin == null || bbox == null) {
      yield 'error: extracción no disponible en este dispositivo';
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
    final part = '$dest.part';
    yield 'Extrayendo ${region.name} del mapa mundial ($build)… '
        'esto tarda unos minutos según el tamaño de la región.';
    final process = await Process.start(bin, [
      'extract',
      '$_buildHost/$build',
      part,
      '--bbox=$bbox',
      // Large regions cap the zoom so the file stays a sane size; street
      // detail (z15) is kept for small ones.
      if (region.maxZoom != null) '--maxzoom=${region.maxZoom}',
    ]);
    final buffer = StringBuffer();
    await for (final chunk in StreamGroup2.merge([
      process.stdout.transform(utf8.decoder),
      process.stderr.transform(utf8.decoder),
    ])) {
      buffer.write(chunk);
      for (final line in chunk.split('\n')) {
        final t = line.trim();
        if (t.isNotEmpty) yield t;
      }
    }
    final code = await process.exitCode;
    if (code == 0 && File(part).existsSync()) {
      File(part).renameSync(dest);
      yield 'listo: ${region.name} instalado';
    } else {
      try {
        File(part).deleteSync();
      } catch (_) {}
      yield 'error: la extracción falló (código $code). '
          '${buffer.toString().split('\n').where((l) => l.contains('error')).join(' ')}';
    }
  }
}

/// Tiny two-stream merge to avoid a package dependency.
class StreamGroup2 {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    final controller = StreamController<T>();
    var active = streams.length;
    for (final s in streams) {
      s.listen(controller.add, onError: controller.addError, onDone: () {
        active--;
        if (active == 0) controller.close();
      });
    }
    return controller.stream;
  }
}
