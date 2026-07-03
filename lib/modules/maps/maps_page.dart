import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../core/prepper_library.dart';
import 'location_service.dart';

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
  final MapController _map = MapController();
  List<File> _regions = [];
  File? _selected;
  PmTilesVectorTileProvider? _provider;
  vtr.Theme? _theme;
  String? _error;
  bool _loading = false;

  // GPS state.
  Position? _me; // last known device position
  StreamSubscription<Position>? _posSub;
  bool _following = false; // keep the map centered on the device
  bool _locating = false; // a fix is in progress
  LatLng? _destination; // "where to go" marker set by tapping the map

  @override
  void initState() {
    super.initState();
    loadMapTheme().then((t) {
      if (mounted) setState(() => _theme = t);
    });
    _refresh();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  /// Requests permission, gets a fix, centers the map on it and starts
  /// follow mode. Shows a clear message if GPS is off or denied.
  Future<void> _locateMe() async {
    setState(() => _locating = true);
    final result = await LocationService.current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (!result.isOk) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    final pos = result.position!;
    setState(() {
      _me = pos;
      _following = true;
    });
    _map.move(LatLng(pos.latitude, pos.longitude), 15);
    _startFollowing();
  }

  void _startFollowing() {
    _posSub?.cancel();
    _posSub = LocationService.stream().listen((pos) {
      if (!mounted) return;
      setState(() => _me = pos);
      if (_following) {
        _map.move(LatLng(pos.latitude, pos.longitude), _map.camera.zoom);
      }
    });
  }

  void _toggleFollow() {
    setState(() => _following = !_following);
    if (_following && _me != null) {
      _map.move(LatLng(_me!.latitude, _me!.longitude), _map.camera.zoom);
    }
  }

  /// Tapping the map marks a destination; we then show distance + bearing
  /// from the device to it. Tapping the same spot again clears it.
  void _onMapTap(LatLng point) {
    setState(() {
      if (_destination != null &&
          LocationService.distanceMeters(_destination!.latitude,
                  _destination!.longitude, point.latitude, point.longitude) <
              30) {
        _destination = null;
      } else {
        _destination = point;
      }
    });
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
      floatingActionButton: _regions.isEmpty || _error != null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_me != null)
                  FloatingActionButton.small(
                    heroTag: 'follow',
                    tooltip: _following
                        ? 'Seguimiento activo (tocar para fijar)'
                        : 'Reanudar seguimiento',
                    backgroundColor: _following
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surface,
                    foregroundColor: _following
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    onPressed: _toggleFollow,
                    child: const Icon(Icons.navigation),
                  ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'locate',
                  tooltip: 'Mi ubicación (GPS)',
                  onPressed: _locating ? null : _locateMe,
                  child: _locating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
      body: _regions.isEmpty
          ? _EmptyMaps(dir: PrepperLibrary.instance.mapsDir.path)
          : _error != null
              ? Center(child: Text(_error!))
              : _loading || _provider == null || _theme == null
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        FlutterMap(
                          mapController: _map,
                          options: MapOptions(
                            // Centered on Honduras by default; the map pans to
                            // wherever the loaded region covers.
                            initialCenter: const LatLng(14.75, -86.25),
                            initialZoom: 7,
                            onTap: (_, point) => _onMapTap(point),
                            // Any manual gesture drops follow mode so the map
                            // doesn't fight the user.
                            onPositionChanged: (pos, hasGesture) {
                              if (hasGesture && _following) {
                                setState(() => _following = false);
                              }
                            },
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
                            // Straight line from me to the destination.
                            if (_me != null && _destination != null)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: [
                                      LatLng(_me!.latitude, _me!.longitude),
                                      _destination!,
                                    ],
                                    strokeWidth: 3,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.7),
                                  ),
                                ],
                              ),
                            // Accuracy circle around the device position.
                            if (_me != null)
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point:
                                        LatLng(_me!.latitude, _me!.longitude),
                                    radius: _me!.accuracy,
                                    useRadiusInMeter: true,
                                    color: Colors.blue.withValues(alpha: 0.15),
                                    borderColor:
                                        Colors.blue.withValues(alpha: 0.4),
                                    borderStrokeWidth: 1,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                if (_destination != null)
                                  Marker(
                                    point: _destination!,
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.topCenter,
                                    child: const Icon(Icons.location_on,
                                        color: Colors.red, size: 40),
                                  ),
                                if (_me != null)
                                  Marker(
                                    point:
                                        LatLng(_me!.latitude, _me!.longitude),
                                    width: 24,
                                    height: 24,
                                    child: const _MyLocationDot(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        // Readout: coordinates, accuracy, and distance/bearing
                        // to the marked destination ("dónde ir").
                        if (_me != null)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: _LocationReadout(
                              me: _me!,
                              destination: _destination,
                            ),
                          ),
                      ],
                    ),
    );
  }
}

/// The pulsing blue dot marking the device's own position.
class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Bottom overlay showing exact coordinates, GPS accuracy and, when a
/// destination is marked, the straight-line distance and compass bearing.
class _LocationReadout extends StatelessWidget {
  const _LocationReadout({required this.me, this.destination});
  final Position me;
  final LatLng? destination;

  String _fmtDistance(double m) {
    if (m < 1000) return '${m.toStringAsFixed(0)} m';
    return '${(m / 1000).toStringAsFixed(m < 10000 ? 2 : 1)} km';
  }

  String _compass(double bearing) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    final i = ((bearing % 360) / 45).round() % 8;
    return dirs[i];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String? destLine;
    if (destination != null) {
      final dist = LocationService.distanceMeters(me.latitude, me.longitude,
          destination!.latitude, destination!.longitude);
      final brg = LocationService.bearing(me.latitude, me.longitude,
          destination!.latitude, destination!.longitude);
      destLine = 'Destino: ${_fmtDistance(dist)} hacia el '
          '${_compass(brg)} (${brg.toStringAsFixed(0)}°)';
    }
    return Card(
      color: scheme.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${me.latitude.toStringAsFixed(5)}, '
                    '${me.longitude.toStringAsFixed(5)}  '
                    '· ±${me.accuracy.toStringAsFixed(0)} m',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (destLine != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.turn_right, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(destLine,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Toca el mapa para marcar a dónde quieres ir.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6))),
              ),
          ],
        ),
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
