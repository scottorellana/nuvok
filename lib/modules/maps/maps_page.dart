import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../core/prepper_library.dart';

/// Loads the bundled Protomaps light v4 style and simplifies its text-field
/// expressions: the upstream theme uses experimental `pgf:` glyph expressions
/// that the Flutter renderer cannot evaluate, which silently drops all map
/// labels. Spanish names are preferred, falling back to the local name.
Future<vtr.Theme> loadMapTheme() async {
  final raw = await rootBundle.loadString('assets/map_theme_light_v4.json');
  final style = jsonDecode(raw) as Map<String, dynamic>;
  for (final layer in (style['layers'] as List).cast<Map<String, dynamic>>()) {
    final layout = layer['layout'] as Map<String, dynamic>?;
    if (layout != null && layout.containsKey('text-field')) {
      layout['text-field'] = [
        'coalesce',
        ['get', 'name:es'],
        ['get', 'name'],
      ];
    }
  }
  return vtr.ThemeReader().read(style);
}

/// Cache directory for rendered tiles, keyed by the map file's identity
/// (name + size + mtime). If the .pmtiles file is replaced or was copied
/// mid-write and later fixed, a fresh cache is used automatically, so stale
/// or corrupt tiles can never survive a file change.
Directory tileCacheDirFor(File mapFile) {
  final stat = mapFile.statSync();
  final name = mapFile.uri.pathSegments.last.replaceAll('.pmtiles', '');
  final key = '$name-${stat.size}-${stat.modified.millisecondsSinceEpoch}';
  return Directory(
      '${PrepperLibrary.instance.root.path}/.tilecache/$key');
}

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  List<File> _regions = [];
  File? _selected;
  PmTilesVectorTileProvider? _provider;
  vtr.Theme? _theme;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    loadMapTheme().then((t) {
      if (mounted) setState(() => _theme = t);
    });
    _refresh();
  }

  void _refresh({bool clearCache = false}) {
    if (clearCache) {
      final cacheRoot =
          Directory('${PrepperLibrary.instance.root.path}/.tilecache');
      try {
        if (cacheRoot.existsSync()) cacheRoot.deleteSync(recursive: true);
      } catch (_) {}
    }
    setState(() {
      _regions = PrepperLibrary.instance.listMaps();
      final current = _selected;
      if (_regions.isNotEmpty &&
          (current == null || clearCache)) {
        _openRegion(current ?? _regions.first);
      }
    });
  }

  Future<void> _openRegion(File f) async {
    setState(() {
      _selected = f;
      _provider = null;
      _error = null;
      _loading = true;
    });
    try {
      final provider = await PmTilesVectorTileProvider.fromSource(f.path);
      if (mounted) setState(() => _provider = provider);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir la región: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapas offline'),
        actions: [
          if (_regions.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<String>(
                value: _selected?.path,
                underline: const SizedBox.shrink(),
                items: [
                  for (final f in _regions)
                    DropdownMenuItem(
                      value: f.path,
                      child: Text(f.uri.pathSegments.last),
                    ),
                ],
                onChanged: (path) {
                  if (path != null) _openRegion(File(path));
                },
              ),
            ),
          IconButton(
            tooltip: 'Actualizar (limpia la caché de tiles)',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(clearCache: true),
          ),
        ],
      ),
      body: _regions.isEmpty
          ? _EmptyMaps(dir: PrepperLibrary.instance.mapsDir.path)
          : _error != null
              ? Center(child: Text(_error!))
              : _loading || _provider == null || _theme == null
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                      options: const MapOptions(
                        // Centered on Honduras by default; the map pans to
                        // wherever the loaded region covers.
                        initialCenter: LatLng(14.75, -86.25),
                        initialZoom: 7,
                      ),
                      children: [
                        VectorTileLayer(
                          // build.protomaps.com serves basemap schema v4.
                          theme: _theme!,
                          tileProviders: TileProviders({
                            'protomaps': _provider!,
                          }),
                          maximumZoom: 15,
                          cacheFolder: () async =>
                              tileCacheDirFor(_selected!),
                        ),
                      ],
                    ),
    );
  }
}

class _EmptyMaps extends StatelessWidget {
  const _EmptyMaps({required this.dir});
  final String dir;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 72),
            const SizedBox(height: 16),
            Text('Sin mapas todavía',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Copia archivos de región .pmtiles a:\n$dir\n\n'
              'Puedes generarlos gratis en maps.protomaps.com/builds '
              'o descargar extractos regionales — el Depósito incluye '
              'las instrucciones.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
