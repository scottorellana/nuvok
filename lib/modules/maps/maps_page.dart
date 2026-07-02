import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

import '../../core/prepper_library.dart';

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  List<File> _regions = [];
  File? _selected;
  PmTilesVectorTileProvider? _provider;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _regions = PrepperLibrary.instance.listMaps();
      if (_regions.isNotEmpty && _selected == null) {
        _openRegion(_regions.first);
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
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _regions.isEmpty
          ? _EmptyMaps(dir: PrepperLibrary.instance.mapsDir.path)
          : _error != null
              ? Center(child: Text(_error!))
              : _loading || _provider == null
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                      options: const MapOptions(
                        initialCenter: LatLng(19.43, -99.13),
                        initialZoom: 5,
                      ),
                      children: [
                        VectorTileLayer(
                          theme: ProtomapsThemes.lightV3(),
                          tileProviders: TileProviders({
                            'protomaps': _provider!,
                          }),
                          maximumZoom: 15,
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
