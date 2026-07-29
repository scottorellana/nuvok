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

import '../../core/nuvok_library.dart';
import '../../core/nuvok_colors.dart';
import '../../core/locale_service.dart';
import '../../core/shell_nav.dart';
import '../depot/map_catalog.dart';
import '../mesh/mesh_service.dart';
import '../mesh/position_store.dart';
import 'composite_tile_provider.dart';
import 'download_from_here.dart';
import 'hybrid_tile_provider.dart';
import 'location_service.dart';
import 'map_coverage.dart';
import 'map_focus.dart';
import 'map_overlays.dart';
import 'place_search.dart';
import 'poi_extractor.dart';
import 'roads_router.dart';

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
  return Directory('${NuvokLibrary.instance.root.path}/.tilecache/$key');
}

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  final MapController _map = MapController();
  List<File> _regions = [];
  // Multiple sources: all installed .pmtiles load as one virtual surface.
  CompositeTileProvider? _composite;
  VectorTileProvider? _provider; // composite or hybrid wrapper
  List<MapCoverage> _coverages = []; // for drawing download outlines
  vtr.Theme? _theme;
  String? _error;
  bool _loading = false;
  // Hybrid mode toggle: fill gaps with online tiles when available.
  bool _hybridMode = false;

  // GPS state.
  Position? _me; // last known device position
  StreamSubscription<Position>? _posSub;
  bool _following = false; // keep the map centered on the device
  bool _locating = false; // a fix is in progress
  LatLng? _destination; // "where to go" marker set by tapping the map
  List<LatLng>? _route; // street-following route to the destination
  double? _routeMeters;
  bool _routing = false;
  RouteProfile _profile = RouteProfile.vehicle;

  // POIs from the map data.
  final Set<PoiCategory> _activeCategories = {
    PoiCategory.health,
    PoiCategory.pharmacy,
    PoiCategory.food,
    PoiCategory.fuel,
  };
  List<MapPoi> _pois = [];
  bool _loadingPois = false;
  Timer? _poiDebounce;

  // User overlays (custom points + tactical layers).
  final _overlays = OverlayStore.instance;
  bool _showOverlays = true;
  // Draw mode: when set, taps add vertices to a new area/line overlay.
  OverlayKind? _drawKind;
  final List<LatLng> _drawPoints = [];

  @override
  void initState() {
    super.initState();
    loadMapTheme().then((t) {
      if (mounted) setState(() => _theme = t);
    });
    _overlays.load().then((_) {
      if (mounted) setState(() {});
    });
    _refresh();
    // Mesh teammates / SOS positions repaint the map as they arrive.
    PositionStore.instance.peers.addListener(_onPeersChanged);
    // Overlays tácticos que llegan por el mesh repintan el mapa.
    _overlays.addListener(_onPeersChanged);
    // "Show this on the map" requests from the SOS alert or other modules.
    MapFocus.request.addListener(_onFocusRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFocusRequest());
  }

  void _onPeersChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusRequest() {
    final target = MapFocus.request.value;
    if (target == null || !mounted) return;
    MapFocus.request.value = null;
    setState(() => _following = false);
    _map.move(target, 15);
  }

  @override
  void dispose() {
    PositionStore.instance.peers.removeListener(_onPeersChanged);
    MapFocus.request.removeListener(_onFocusRequest);
    _overlays.removeListener(_onPeersChanged);
    _posSub?.cancel();
    _poiDebounce?.cancel();
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

  /// Tap behavior depends on the mode:
  /// - draw mode: add a vertex to the area/line being drawn
  /// - normal: mark/clear a destination for "where to go"
  void _onMapTap(LatLng point) {
    if (_drawKind != null) {
      setState(() => _drawPoints.add(point));
      return;
    }
    setState(() {
      // Any change to the destination invalidates the current route.
      _route = null;
      _routeMeters = null;
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

  /// Computes a street-following route from the device (GPS) to the marked
  /// destination, over the roads in the loaded .pmtiles.
  Future<void> _computeRoute() async {
    final provider = _provider;
    final dest = _destination;
    if (provider == null || dest == null) return;
    // Origin: current GPS fix, or get one now.
    LatLng? origin = _me != null ? LatLng(_me!.latitude, _me!.longitude) : null;
    if (origin == null) {
      final res = await LocationService.current();
      if (!mounted) return;
      if (!res.isOk) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Para trazar la ruta necesito tu ubicación. '
                '${res.message}')));
        return;
      }
      _me = res.position;
      origin = LatLng(res.position!.latitude, res.position!.longitude);
    }
    setState(() => _routing = true);
    try {
      // Gates and risk zones the user marked constrain the route.
      final restrictions = RouteRestrictions(
        barriers: [
          for (final o in _overlays.overlays)
            if (o.kind == OverlayKind.barrier) o.anchor,
        ],
        riskZones: [
          for (final o in _overlays.overlays)
            if (o.kind == OverlayKind.riskZone) o.points,
        ],
      );
      final outcome = await RoadRouter.route(
        provider: provider,
        origin: origin,
        destination: dest,
        zoom: _map.camera.zoom.round(),
        profile: _profile,
        restrictions: restrictions,
      );
      if (!mounted) return;
      if (outcome.status != RouteStatus.ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(outcome.message)));
        setState(() {
          _route = null;
          _routeMeters = null;
        });
        return;
      }
      if (!outcome.result!.restricted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.orange.shade800,
          content: const Text('⚠️ Sin ruta limpia: esta ruta puede cruzar '
              'calles privadas, portones o zonas de riesgo.'),
          duration: const Duration(seconds: 5),
        ));
      }
      setState(() {
        _route = outcome.result!.path;
        _routeMeters = outcome.result!.distanceMeters;
      });
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  /// "Llévame a…": search places/POIs/overlays by name; picking one marks it
  /// as destination, centers the camera and traces the street route.
  Future<void> _openSearch() async {
    final provider = _provider;
    if (provider == null || _regions.isEmpty) return;
    // Build a cache key from all loaded map files so the place index is
    // shared across sessions with the same map set.
    final cacheKey = _regions
        .map((f) => '${f.uri.pathSegments.last}:${f.statSync().size}')
        .join('|');
    final me = _me != null ? LatLng(_me!.latitude, _me!.longitude) : null;
    final target = await showDialog<(String, LatLng)>(
      context: context,
      builder: (context) => _PlaceSearchDialog(
        provider: provider,
        cacheKey: cacheKey,
        pois: _pois,
        overlays: _overlays.overlays,
        near: me,
      ),
    );
    if (target == null || !mounted) return;
    setState(() {
      _destination = target.$2;
      _route = null;
      _routeMeters = null;
      _following = false;
    });
    _map.move(target.$2, 15);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Destino: ${target.$1} — trazando ruta…'),
        duration: const Duration(seconds: 2)));
    await _computeRoute();
  }

  void _toggleProfile() {
    setState(() {
      _profile = _profile == RouteProfile.vehicle
          ? RouteProfile.walk
          : RouteProfile.vehicle;
      // A profile change invalidates the current route.
      _route = null;
      _routeMeters = null;
    });
  }

  /// Auto-loads POIs once the map settles at city zoom (>= 13), so hospitals,
  /// pharmacies and stores appear without opening any panel. Debounced to
  /// avoid re-reading tiles on every frame of a pan/zoom.
  void _schedulePoiLoad(double zoom) {
    _poiDebounce?.cancel();
    if (zoom < 13) {
      if (_pois.isNotEmpty) setState(() => _pois = []);
      return;
    }
    _poiDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _loadPois();
    });
  }

  /// Loads POIs (hospitals, pharmacies, …) for the current viewport.
  Future<void> _loadPois() async {
    final provider = _provider;
    if (provider == null || _activeCategories.isEmpty) {
      setState(() => _pois = []);
      return;
    }
    setState(() => _loadingPois = true);
    try {
      final camera = _map.camera;
      final bounds = camera.visibleBounds;
      final pois = await PoiExtractor.extract(
        provider: provider,
        bounds: bounds,
        zoom: camera.zoom.round(),
        categories: _activeCategories,
      );
      if (mounted) setState(() => _pois = pois);
    } catch (_) {
      // Ignore — POIs are best-effort.
    } finally {
      if (mounted) setState(() => _loadingPois = false);
    }
  }

  /// Adds a custom point overlay (shelter, water, meeting point, …) at [point].
  Future<void> _addCustomPoint(LatLng point) async {
    final result = await showModalBottomSheet<(OverlayKind, String?)>(
      context: context,
      builder: (context) => _AddPointSheet(point: point),
    );
    if (result == null) return;
    final overlay = MapOverlay(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: result.$1,
      points: [point],
      name: result.$2,
    );
    await _overlays.add(overlay);
    // Mapa táctico compartido: lo que marcas lo ve todo el grupo por el mesh.
    unawaited(MeshService.instance.shareOverlayFeature(overlay.toFeature()));
    if (mounted) setState(() {});
  }

  /// Starts drawing an area (zone) or line (route). Taps then add vertices.
  void _startDraw(OverlayKind kind) {
    setState(() {
      _drawKind = kind;
      _drawPoints.clear();
      _destination = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Dibujando ${kind.label}: toca el mapa para agregar '
          'puntos, luego pulsa ✓'),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _finishDraw() async {
    final kind = _drawKind;
    final minPts = kind != null && kind.isArea ? 3 : 2;
    if (kind == null || _drawPoints.length < minPts) {
      setState(() {
        _drawKind = null;
        _drawPoints.clear();
      });
      return;
    }
    int? danger;
    if (kind == OverlayKind.riskZone) {
      danger = await showDialog<int>(
        context: context,
        builder: (context) => _DangerLevelDialog(),
      );
    }
    final overlay = MapOverlay(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      points: List.of(_drawPoints),
      dangerLevel: danger,
    );
    await _overlays.add(overlay);
    unawaited(MeshService.instance.shareOverlayFeature(overlay.toFeature()));
    if (mounted) {
      setState(() {
        _drawKind = null;
        _drawPoints.clear();
      });
    }
  }

  void _cancelDraw() {
    setState(() {
      _drawKind = null;
      _drawPoints.clear();
    });
  }

  void _refresh({bool clearCache = false}) {
    if (clearCache) {
      final cacheRoot =
          Directory('${NuvokLibrary.instance.root.path}/.tilecache');
      try {
        if (cacheRoot.existsSync()) cacheRoot.deleteSync(recursive: true);
      } catch (_) {}
    }
    setState(() {
      _regions = NuvokLibrary.instance.listMaps();
    });
    // Load all installed maps as a single composite surface.
    if (_regions.isNotEmpty) {
      _loadAllRegions();
    } else {
      setState(() {
        _composite = null;
        _provider = null;
        _coverages = [];
      });
    }
  }

  /// Loads every installed .pmtiles into a CompositeTileProvider so the user
  /// sees all downloaded regions as one continuous map surface — no need to
  /// switch between regions manually.
  Future<void> _loadAllRegions() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final providers = <PmTilesVectorTileProvider>[];
      final coverages = <MapCoverage>[];
      for (final f in _regions) {
        try {
          final p = await PmTilesVectorTileProvider.fromSource(f.path);
          providers.add(p);
          coverages.add(MapCoverageReader.fromProvider(f, p));
        } catch (_) {
          // Skip corrupt/incomplete files — don't fail everything.
        }
      }
      if (!mounted) return;
      final composite = CompositeTileProvider.fromProviders(providers);
      setState(() {
        _composite = composite;
        _coverages = coverages;
        _provider = _buildProvider(composite);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los mapas: $e';
          _loading = false;
        });
      }
    }
  }

  /// Builds the active tile provider: composite-only or hybrid (with online
  /// fallback) depending on the user's toggle.
  VectorTileProvider _buildProvider(CompositeTileProvider composite) {
    if (_hybridMode && !composite.isEmpty) {
      final online = NetworkVectorTileProvider(
        urlTemplate: kOnlineFallbackUrl,
        type: TileProviderType.vector,
      );
      return HybridTileProvider(composite, online);
    }
    return composite;
  }

  /// Toggles hybrid mode and rebuilds the provider.
  void _toggleHybrid() {
    setState(() {
      _hybridMode = !_hybridMode;
      if (_composite != null) {
        _provider = _buildProvider(_composite!);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_hybridMode
          ? 'Modo híbrido: rellenando huecos con internet cuando haya.'
          : 'Solo offline: sin datos externos.'),
      duration: const Duration(seconds: 2),
    ));
  }

  /// "Descargar desde aquí": takes the current map center, asks for a radius,
  /// and extracts that area from the Protomaps daily build — same as Google
  /// Maps' offline download flow. Desktop-only (needs pmtiles CLI).
  Future<void> _downloadFromHere() async {
    final center = _map.camera.center;
    // Check if already covered.
    if (isAlreadyCovered(center, _coverages)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Esta área ya está descargada.'),
      ));
      return;
    }
    // Ask the user for a radius.
    final radius = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descargar área desde aquí'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Centro: ${center.latitude.toStringAsFixed(3)}, '
                '${center.longitude.toStringAsFixed(3)}'),
            const SizedBox(height: 12),
            const Text('¿Qué tan grande?'),
          ],
        ),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (label, km) in kDownloadRadiusOptions)
                TextButton(
                  onPressed: () => Navigator.pop(context, km),
                  child: Text(label),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
    if (radius == null || !mounted) return;

    // Create a region for the selected area and extract it.
    final region = regionFromCenter(center, radius);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Descargando ${region.name}…'),
      duration: const Duration(seconds: 3),
    ));
    String? lastLine;
    await for (final line in MapExtractor.extract(region)) {
      if (!mounted) return;
      lastLine = line;
    }
    if (!mounted) return;
    if (lastLine != null && lastLine.startsWith('error')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ $lastLine'),
        duration: const Duration(seconds: 5),
      ));
    } else {
      // Reload to pick up the new map file.
      _refresh(clearCache: true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${region.name} instalado.'),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _regions.isEmpty ? null : _buildLayersDrawer(),
      appBar: AppBar(
        // En teléfonos los 4-5 iconos de acción dejan ~100px para el título:
        // el texto debe ceder (ellipsis) y el chip de regiones no cabe.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text('Mapas offline',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (_regions.length > 1 && MediaQuery.of(context).size.width >= 560)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('${_regions.length} regiones'),
                  avatar: const Icon(Icons.layers, size: 16),
                ),
              ),
          ],
        ),
        actions: [
          // Download area from current map center (desktop with pmtiles CLI).
          if (MapExtractor.available && _provider != null)
            IconButton(
              tooltip: 'Descargar área desde aquí',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _downloadFromHere(),
            ),
          // Hybrid mode toggle: fill gaps with online tiles.
          if (_provider != null)
            IconButton(
              tooltip: _hybridMode
                  ? 'Modo híbrido ON (tocar para solo offline)'
                  : 'Solo offline (tocar para modo híbrido)',
              icon: Icon(_hybridMode ? Icons.cloud : Icons.cloud_off),
              color: _hybridMode ? Theme.of(context).colorScheme.primary : null,
              onPressed: _toggleHybrid,
            ),
          IconButton(
            tooltip: 'Buscar lugar y llevarme ahí',
            icon: const Icon(Icons.search),
            onPressed:
                _regions.isEmpty || _provider == null ? null : _openSearch,
          ),
          IconButton(
            tooltip: 'Capas: POIs y capas tácticas',
            icon: Badge(
              isLabelVisible: _loadingPois,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.layers),
            ),
            onPressed: _regions.isEmpty
                ? null
                : () => _scaffoldKey.currentState?.openEndDrawer(),
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
          : _drawKind != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'cancelDraw',
                      tooltip: 'Cancelar',
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      onPressed: _cancelDraw,
                      child: const Icon(Icons.close),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'finishDraw',
                      tooltip: 'Terminar',
                      onPressed: _finishDraw,
                      child: const Icon(Icons.check),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_destination != null)
                      FloatingActionButton.small(
                        heroTag: 'profile',
                        tooltip: _profile == RouteProfile.vehicle
                            ? 'Ruta en vehículo (tocar para ir a pie)'
                            : 'Ruta a pie (tocar para vehículo)',
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        onPressed: _toggleProfile,
                        child: Icon(_profile == RouteProfile.vehicle
                            ? Icons.directions_car
                            : Icons.directions_walk),
                      ),
                    if (_destination != null) const SizedBox(height: 8),
                    if (_destination != null)
                      FloatingActionButton.extended(
                        heroTag: 'route',
                        tooltip: 'Trazar ruta por calles hasta el destino',
                        onPressed: _routing ? null : _computeRoute,
                        icon: _routing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.directions),
                        label: Text(_route != null ? 'Recalcular' : 'Ruta'),
                      ),
                    if (_destination != null) const SizedBox(height: 8),
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
          ? _EmptyMaps(
              dir: NuvokLibrary.instance.mapsDir.path,
              onInstalled: () => _refresh(clearCache: true))
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
                            onLongPress: (_, point) {
                              if (_drawKind == null) _addCustomPoint(point);
                            },
                            // Any manual gesture drops follow mode so the map
                            // doesn't fight the user.
                            onPositionChanged: (pos, hasGesture) {
                              if (hasGesture && _following) {
                                setState(() => _following = false);
                              }
                              _schedulePoiLoad(pos.zoom);
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
                              cacheFolder: () async => Directory(
                                  '${NuvokLibrary.instance.root.path}/.tilecache/composite'),
                            ),
                            // Downloaded-area outlines (subtle blue rectangles).
                            if (_coverages.isNotEmpty)
                              PolygonLayer(
                                polygons: [
                                  for (final c in _coverages)
                                    Polygon(
                                      points: c.polygon,
                                      color:
                                          Colors.blue.withValues(alpha: 0.05),
                                      borderColor:
                                          Colors.blue.withValues(alpha: 0.3),
                                      borderStrokeWidth: 1,
                                    ),
                                ],
                              ),
                            // Tactical zones (safe / risk polygons).
                            if (_showOverlays)
                              PolygonLayer(
                                polygons: [
                                  for (final o in _overlays.overlays)
                                    if (o.kind.isArea)
                                      Polygon(
                                        points: o.points,
                                        color: _overlayColor(o)
                                            .withValues(alpha: 0.22),
                                        borderColor: _overlayColor(o),
                                        borderStrokeWidth: 2,
                                      ),
                                ],
                              ),
                            // Evacuation routes + the polygon/line being drawn.
                            if (_showOverlays)
                              PolylineLayer(
                                polylines: [
                                  for (final o in _overlays.overlays)
                                    if (o.kind.isLine)
                                      Polyline(
                                        points: o.points,
                                        strokeWidth: 4,
                                        color: _overlayColor(o),
                                      ),
                                  if (_drawKind != null &&
                                      _drawPoints.length > 1)
                                    Polyline(
                                      points: _drawPoints,
                                      strokeWidth: 3,
                                      color: Colors.orange,
                                    ),
                                ],
                              ),
                            // Route to the destination: the street-following
                            // route when computed, else a straight guide line.
                            if (_route != null)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _route!,
                                    strokeWidth: 5,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              )
                            else if (_me != null && _destination != null)
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
                                        .withValues(alpha: 0.5),
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
                            // POI markers from the map data.
                            MarkerLayer(
                              markers: [
                                for (final p in _pois)
                                  Marker(
                                    point: p.location,
                                    width: 44,
                                    height: 44,
                                    child: Semantics(
                                      button: true,
                                      label:
                                          'Punto de interés ${p.name ?? p.kind}',
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _showPoiInfo(p),
                                        child: Center(
                                          child: _PoiPin(category: p.category),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            // Custom point overlays (shelter, water, …).
                            if (_showOverlays)
                              MarkerLayer(
                                markers: [
                                  for (final o in _overlays.overlays)
                                    if (o.kind.isPoint)
                                      Marker(
                                        point: o.anchor,
                                        width: 44,
                                        height: 44,
                                        child: Semantics(
                                          button: true,
                                          label:
                                              'Marcador ${o.name ?? o.kind.label}',
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _showOverlayInfo(o),
                                            child: Center(
                                              child: _OverlayPin(overlay: o),
                                            ),
                                          ),
                                        ),
                                      ),
                                  // Vertices being drawn.
                                  for (final v in _drawPoints)
                                    Marker(
                                      point: v,
                                      width: 14,
                                      height: 14,
                                      child: const DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            // Mesh teammates and SOS alerts heard offline.
                            MarkerLayer(
                              markers: [
                                for (final p in PositionStore.instance.recent())
                                  Marker(
                                    point: LatLng(p.lat, p.lon),
                                    width: p.isSos ? 46 : 34,
                                    height: p.isSos ? 46 : 34,
                                    child: Tooltip(
                                      message: p.isSos
                                          ? 'SOS: ${p.name} '
                                              '${p.sosNote ?? ''}'
                                          : p.name,
                                      child: p.isSos
                                          ? const Icon(Icons.sos,
                                              color: Colors.red, size: 44)
                                          : CircleAvatar(
                                              backgroundColor:
                                                  Colors.teal.shade700,
                                              child: Text(
                                                p.name.isEmpty
                                                    ? '?'
                                                    : p.name[0].toUpperCase(),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                    ),
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
                              routeMeters: _routeMeters,
                              profileEmoji: _profile == RouteProfile.vehicle
                                  ? '🚗'
                                  : '🚶',
                            ),
                          ),
                        if (_drawKind != null)
                          Positioned(
                            left: 12,
                            right: 12,
                            top: 12,
                            child: Card(
                              color: NuvokColors.cautionSurface,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  'Dibujando ${_drawKind!.label} · '
                                  '${_drawPoints.length} puntos. Toca el mapa '
                                  'para agregar, ✓ para terminar.',
                                  style: const TextStyle(
                                    color: NuvokColors.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // ATRIBUCIÓN OBLIGATORIA (ODbL): los datos son de
                        // OpenStreetMap y su licencia exige el crédito donde
                        // se muestra el mapa, no escondido en otra pantalla.
                        Positioned(
                          left: 6,
                          bottom: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              child: Text(
                                tr(context, 'mapAttribution'),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Color _overlayColor(MapOverlay o) {
    switch (o.kind) {
      case OverlayKind.safeZone:
        return Colors.green;
      case OverlayKind.riskZone:
        // Deeper red with higher danger level.
        return Color.lerp(Colors.orange, Colors.red.shade900,
            ((o.dangerLevel ?? 3) - 1) / 4)!;
      case OverlayKind.evacuationRoute:
        return Colors.deepPurple;
      case OverlayKind.shelter:
        return Colors.brown;
      case OverlayKind.water:
        return Colors.lightBlue;
      case OverlayKind.meetingPoint:
        return Colors.teal;
      case OverlayKind.resource:
        return Colors.indigo;
      case OverlayKind.customPoint:
        return Colors.blueGrey;
      case OverlayKind.barrier:
        return Colors.red.shade900;
    }
  }

  void _showPoiInfo(MapPoi p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _PoiPin(category: p.category),
              const SizedBox(width: 10),
              Expanded(
                child: Text(p.name ?? poiCategoryLabel(p.category),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ]),
            const SizedBox(height: 6),
            Text('${poiCategoryLabel(p.category)} · ${p.kind}'),
            const SizedBox(height: 4),
            Text(
                '${p.location.latitude.toStringAsFixed(5)}, '
                '${p.location.longitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall),
            if (_me != null) ...[
              const SizedBox(height: 8),
              Text(
                'A ${_fmtKm(LocationService.distanceMeters(_me!.latitude, _me!.longitude, p.location.latitude, p.location.longitude))} '
                'de tu ubicación',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOverlayInfo(MapOverlay o) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.name ?? o.kind.label,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(o.kind.label +
                (o.dangerLevel != null
                    ? ' · peligrosidad ${o.dangerLevel}/5'
                    : '')),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label:
                    const Text('Eliminar', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  await _overlays.remove(o.id);
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtKm(double m) => m < 1000
      ? '${m.toStringAsFixed(0)} m'
      : '${(m / 1000).toStringAsFixed(1)} km';

  Widget _buildLayersDrawer() {
    return Drawer(
      child: SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheet) {
            void toggleCat(PoiCategory c, bool on) {
              setSheet(() {
                if (on) {
                  _activeCategories.add(c);
                } else {
                  _activeCategories.remove(c);
                }
              });
              setState(() {});
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Puntos de interés del mapa',
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        FilledButton.tonalIcon(
                          icon: _loadingPois
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.search, size: 18),
                          label: const Text('Buscar aquí'),
                          onPressed: () {
                            Navigator.pop(context);
                            _loadPois();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in PoiCategory.values)
                          FilterChip(
                            avatar: Icon(poiCategoryIcon(c),
                                size: 18, color: poiCategoryColor(c)),
                            label: Text(poiCategoryLabel(c)),
                            selected: _activeCategories.contains(c),
                            onSelected: (v) => toggleCat(c, v),
                          ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Capas tácticas',
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        Switch(
                          value: _showOverlays,
                          onChanged: (v) {
                            setSheet(() => _showOverlays = v);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const Text(
                      'Mantén pulsado el mapa para agregar un punto '
                      '(refugio, agua, reunión). O dibuja un área o ruta:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _drawButton(
                            OverlayKind.safeZone, Icons.shield_outlined),
                        _drawButton(OverlayKind.riskZone, Icons.warning_amber),
                        _drawButton(
                            OverlayKind.evacuationRoute, Icons.route_outlined),
                      ],
                    ),
                    if (_overlays.overlays.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('${_overlays.overlays.length} elementos guardados',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _drawButton(OverlayKind kind, IconData icon) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(kind.label),
      onPressed: () {
        Navigator.pop(context);
        _startDraw(kind);
      },
    );
  }
}

/// Colored map pin for an auto-detected POI category.
class _PoiPin extends StatelessWidget {
  const _PoiPin({required this.category});
  final PoiCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: poiCategoryColor(category),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
      ),
      child: Icon(poiCategoryIcon(category), size: 16, color: Colors.white),
    );
  }
}

/// Pin for a user-created custom point overlay.
class _OverlayPin extends StatelessWidget {
  const _OverlayPin({required this.overlay});
  final MapOverlay overlay;

  IconData get _icon {
    switch (overlay.kind) {
      case OverlayKind.shelter:
        return Icons.home_outlined;
      case OverlayKind.water:
        return Icons.water_drop;
      case OverlayKind.meetingPoint:
        return Icons.groups;
      case OverlayKind.resource:
        return Icons.inventory_2_outlined;
      case OverlayKind.barrier:
        return Icons.block;
      default:
        return Icons.push_pin;
    }
  }

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (overlay.kind) {
      case OverlayKind.shelter:
        color = Colors.brown;
        break;
      case OverlayKind.water:
        color = Colors.lightBlue;
        break;
      case OverlayKind.meetingPoint:
        color = Colors.teal;
        break;
      case OverlayKind.resource:
        color = Colors.indigo;
        break;
      case OverlayKind.barrier:
        color = Colors.red.shade900;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
      ),
      child: Icon(_icon, size: 18, color: Colors.white),
    );
  }
}

String poiCategoryLabel(PoiCategory c) {
  switch (c) {
    case PoiCategory.health:
      return 'Hospitales';
    case PoiCategory.pharmacy:
      return 'Farmacias';
    case PoiCategory.fuel:
      return 'Combustible';
    case PoiCategory.food:
      return 'Tiendas';
    case PoiCategory.safety:
      return 'Seguridad';
    case PoiCategory.water:
      return 'Agua';
  }
}

IconData poiCategoryIcon(PoiCategory c) {
  switch (c) {
    case PoiCategory.health:
      return Icons.local_hospital;
    case PoiCategory.pharmacy:
      return Icons.local_pharmacy;
    case PoiCategory.fuel:
      return Icons.local_gas_station;
    case PoiCategory.food:
      return Icons.storefront;
    case PoiCategory.safety:
      return Icons.local_police;
    case PoiCategory.water:
      return Icons.water_drop;
  }
}

Color poiCategoryColor(PoiCategory c) {
  switch (c) {
    case PoiCategory.health:
      return Colors.red.shade700;
    case PoiCategory.pharmacy:
      return Colors.green.shade700;
    case PoiCategory.fuel:
      return Colors.orange.shade800;
    case PoiCategory.food:
      return Colors.blue.shade700;
    case PoiCategory.safety:
      return Colors.indigo;
    case PoiCategory.water:
      return Colors.cyan.shade700;
  }
}

/// Bottom sheet to pick the kind of custom point to drop.
class _AddPointSheet extends StatelessWidget {
  const _AddPointSheet({required this.point});
  final LatLng point;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    OverlayKind selected = OverlayKind.customPoint;
    return StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agregar punto',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final k in [
                  OverlayKind.shelter,
                  OverlayKind.water,
                  OverlayKind.meetingPoint,
                  OverlayKind.resource,
                  OverlayKind.barrier,
                  OverlayKind.customPoint,
                ])
                  ChoiceChip(
                    label: Text(k.label),
                    selected: selected == k,
                    onSelected: (_) => setSheet(() => selected = k),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nombre (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, (
                  selected,
                  controller.text.trim().isEmpty ? null : controller.text.trim()
                )),
                child: const Text('Agregar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to pick a danger level (1..5) when drawing a risk zone.
class _DangerLevelDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nivel de peligrosidad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            ListTile(
              leading: Icon(Icons.warning_amber,
                  color: Color.lerp(
                      Colors.orange, Colors.red.shade900, (i - 1) / 4)),
              title: Text('Nivel $i${i == 5 ? ' (máximo)' : ''}'),
              onTap: () => Navigator.pop(context, i),
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
  const _LocationReadout(
      {required this.me,
      this.destination,
      this.routeMeters,
      this.profileEmoji = '🚗'});
  final Position me;
  final LatLng? destination;
  final double? routeMeters;
  final String profileEmoji;

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
      if (routeMeters != null) {
        destLine =
            '$profileEmoji Ruta por calles: ${_fmtDistance(routeMeters!)} · '
            '$destLine';
      }
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

/// First-run Maps experience: pick your country (pre-selected from the
/// device locale) and download it RIGHT HERE — no folders, no other sites.
/// The extract streams progress and, when done, [onInstalled] reloads the
/// map so it opens immediately.
class _EmptyMaps extends StatefulWidget {
  const _EmptyMaps({required this.dir, required this.onInstalled});
  final String dir;
  final VoidCallback onInstalled;

  @override
  State<_EmptyMaps> createState() => _EmptyMapsState();
}

class _EmptyMapsState extends State<_EmptyMaps> {
  List<MapRegion>? _regions;
  MapRegion? _selected;
  String? _progress;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final regions = await MapCatalog.load();
    if (!mounted) return;
    // Suggest the device's country ("es_HN" → HN → honduras).
    final locale = Platform.localeName;
    final cc =
        locale.contains('_') ? locale.split('_').last.toUpperCase() : null;
    final suggestedId = cc == null ? null : suggestedRegionId(cc);
    setState(() {
      _regions = regions;
      _selected = regions.firstWhere(
        (r) => r.id == suggestedId,
        orElse: () => regions.first,
      );
    });
  }

  Future<void> _download() async {
    final region = _selected;
    if (region == null || _downloading) return;
    setState(() {
      _downloading = true;
      _progress = '…';
    });
    var failed = false;
    await for (final line in MapExtractor.extract(region)) {
      if (!mounted) return;
      setState(() => _progress = line);
      if (line.startsWith('error')) failed = true;
    }
    if (!mounted) return;
    setState(() => _downloading = false);
    if (!failed && region.installed) {
      widget.onInstalled(); // reload → the map opens right away
    }
  }

  @override
  Widget build(BuildContext context) {
    final regions = _regions;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.travel_explore, size: 72),
              const SizedBox(height: 16),
              Text(tr(context, 'emptyMapsTitle'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(tr(context, 'emptyMapsBody'), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (regions == null)
                const CircularProgressIndicator()
              else ...[
                DropdownMenu<MapRegion>(
                  initialSelection: _selected,
                  width: 320,
                  enabled: !_downloading,
                  dropdownMenuEntries: [
                    for (final r in regions)
                      DropdownMenuEntry(
                        value: r,
                        label: '${r.flag} ${r.name} · ${r.sizeMB} MB',
                      ),
                  ],
                  onSelected: (r) => setState(() => _selected = r),
                ),
                const SizedBox(height: 16),
                if (_downloading || _progress != null) ...[
                  if (_downloading) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(_progress ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _downloading ? null : _download,
                  icon: const Icon(Icons.download),
                  label: Text(
                      '${tr(context, 'downloadMap')} — ${_selected?.name ?? ''}'),
                ),
                const SizedBox(height: 8),
                Text(tr(context, 'needInternetOnce'),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
                TextButton(
                  onPressed:
                      _downloading ? null : () => ShellNav.goDepot(tab: 3),
                  child: Text(tr(context, 'moreCountries')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Search dialog: builds the offline place index on first open (with a
/// progress note), merges places + loaded POIs + named overlays, and returns
/// the chosen (name, location).
class _PlaceSearchDialog extends StatefulWidget {
  const _PlaceSearchDialog({
    required this.provider,
    required this.cacheKey,
    required this.pois,
    required this.overlays,
    this.near,
  });

  final VectorTileProvider provider;
  final String cacheKey;
  final List<MapPoi> pois;
  final List<MapOverlay> overlays;
  final LatLng? near;

  @override
  State<_PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<_PlaceSearchDialog> {
  PlaceIndex? _index;
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    PlaceIndex.forProvider(widget.provider, widget.cacheKey).then((idx) {
      if (mounted) setState(() => _index = idx);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<(String, String, LatLng)> _results() {
    final q = _query.trim();
    if (q.length < 2) return const [];
    final out = <(String, String, LatLng)>[];
    final ql = q.toLowerCase();
    // User's own named points first — they outrank everything.
    for (final o in widget.overlays) {
      final name = o.name;
      if (name != null && name.toLowerCase().contains(ql)) {
        out.add((name, o.kind.label, o.anchor));
      }
    }
    // POIs currently loaded around the viewport (hospitals, pharmacies…).
    for (final p in widget.pois) {
      final name = p.name;
      if (name != null && name.toLowerCase().contains(ql)) {
        out.add((name, p.kind, p.location));
      }
    }
    // Cities and towns from the map itself.
    final idx = _index;
    if (idx != null) {
      for (final e in idx.search(q, near: widget.near)) {
        out.add((e.name, _kindEs(e.kind), e.location));
      }
    }
    return out.take(30).toList();
  }

  static String _kindEs(String kind) {
    switch (kind) {
      case 'locality':
        return 'ciudad/pueblo';
      case 'region':
        return 'departamento';
      case 'neighbourhood':
        return 'colonia/barrio';
      default:
        return kind;
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '¿A dónde vamos? (ciudad, hospital, tu punto…)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              if (_index == null)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Indexando lugares del mapa…',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              Flexible(
                child: results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _query.trim().length < 2
                              ? 'Escribe al menos 2 letras.'
                              : 'Sin resultados en este mapa.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final (name, kind, loc) = results[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place),
                            title: Text(name),
                            subtitle: Text(kind),
                            onTap: () => Navigator.of(context).pop((name, loc)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
