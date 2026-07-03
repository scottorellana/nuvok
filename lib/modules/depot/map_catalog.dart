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
    this.bbox,
    this.url,
  });

  final String id;
  final String name;
  final String flag;
  final int sizeMB;
  final String? bbox; // minLon,minLat,maxLon,maxLat
  final String? url; // direct .pmtiles download when hosted somewhere

  String get fileName => '$id.pmtiles';

  bool get installed => File(
          '${PrepperLibrary.instance.mapsDir.path}/$fileName')
      .existsSync();
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
          sizeMB: (r['sizeMB'] as num?)?.toInt() ?? 0,
          bbox: r['bbox'] as String?,
          url: r['url'] as String?,
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

  /// Latest daily build file name (e.g. 20260702.pmtiles).
  static Future<String?> latestBuild() async {
    try {
      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse('https://build.protomaps.com/builds.json'));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      final builds = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
      final keys = [
        for (final b in builds)
          if ((b['key'] as String?)?.endsWith('.pmtiles') ?? false)
            b['key'] as String,
      ]..sort();
      return keys.isEmpty ? null : keys.last;
    } catch (_) {
      return null;
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
    yield 'Buscando el build más reciente…';
    final build = await latestBuild();
    if (build == null) {
      yield 'error: no se pudo consultar build.protomaps.com (¿hay internet?)';
      return;
    }
    final dest =
        '${PrepperLibrary.instance.mapsDir.path}/${region.fileName}';
    final part = '$dest.part';
    yield 'Extrayendo ${region.name} de $build (esto tarda unos minutos)…';
    final process = await Process.start(bin, [
      'extract',
      'https://build.protomaps.com/$build',
      part,
      '--bbox=$bbox',
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
