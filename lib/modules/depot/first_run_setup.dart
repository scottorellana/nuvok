// "Prepara tu Nuvok": la pantalla del primer arranque.
//
// El instalador llega ligero (~300 MB) — sin modelo de IA, sin mapas y sin
// enciclopedia. Esta página propone el paquete inicial mientras HAY internet,
// que es antes de la emergencia: la IA elegida por la memoria del equipo, la
// Wikipedia médica del idioma y el mapa del país. No inventa infraestructura:
// encola en el DownloadManager de siempre y el progreso se mira en la pestaña
// Descargas del Depósito.
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import '../../core/nuvok_library.dart';
import '../../core/shell_nav.dart';
import '../ai/active_model.dart';
import '../ai/agents/model_catalog.dart';
import '../ai/ai_engine.dart';
import 'download_manager.dart';
import 'map_catalog.dart';
import 'starter_pack.dart';
import 'starter_plan.dart';

class FirstRunSetupPage extends StatefulWidget {
  const FirstRunSetupPage({
    super.key,
    this.freeRam,
    this.resolveWiki,
    this.isDesktop,
    this.localeCountry,
    this.enqueue,
    this.onGoMaps,
    this.onGoDownloads,
  });

  /// Costuras inyectables: los tests pasan fakes; la app usa los reales
  /// (AiEngine, StarterPack, DownloadManager, ShellNav, Platform).
  final Future<int?> Function()? freeRam;
  final Future<StarterCandidate?> Function()? resolveWiki;
  final bool? isDesktop;
  final String? localeCountry;
  final void Function(StarterDownloadRequest req)? enqueue;
  final VoidCallback? onGoMaps;
  final VoidCallback? onGoDownloads;

  @override
  State<FirstRunSetupPage> createState() => _FirstRunSetupPageState();
}

class _FirstRunSetupPageState extends State<FirstRunSetupPage> {
  ModelEntry? _model;
  StarterCandidate? _wiki;
  bool _wikiLoading = true;
  MapRegion? _region;

  bool get _isDesktop =>
      widget.isDesktop ??
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  String? get _localeCountry {
    if (widget.localeCountry != null) return widget.localeCountry;
    // 'es_HN' / 'es-HN' → 'HN' (mismo parsing que el estado vacío de Mapas).
    final parts = Platform.localeName.split(RegExp('[_-]'));
    return parts.length > 1 ? parts[1] : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ram = await (widget.freeRam ?? AiEngine.freeRamBytes)();
    if (mounted) {
      setState(() => _model =
          resolveStarterModel(isDesktop: _isDesktop, freeRamBytes: ram));
    }
    final regions = await MapCatalog.load();
    final id = suggestedRegionId(_localeCountry);
    if (mounted && id != null) {
      final match = regions.where((r) => r.id == id);
      if (match.isNotEmpty) setState(() => _region = match.first);
    }
    try {
      final w = await (widget.resolveWiki ?? StarterPack.resolveFirstAid)();
      if (mounted) setState(() { _wiki = w; _wikiLoading = false; });
    } catch (_) {
      // Sin internet: la tarjeta lo dice y el botón descarga lo que se pueda.
      if (mounted) setState(() { _wiki = null; _wikiLoading = false; });
    }
  }

  int get _totalBytes =>
      (_model?.sizeBytes ?? 0) + (_wiki?.result.sizeBytes ?? 0);

  void _realEnqueue(StarterDownloadRequest r) {
    DownloadManager.instance.enqueue(
      r.url,
      '${NuvokLibrary.instance.root.path}/${r.relativeDir}/${r.fileName}',
      totalBytes: r.totalBytes,
      sha256Hex: r.sha256Hex,
    );
  }

  void _downloadAll() {
    final model = _model;
    if (model == null) return;
    final reqs = starterDownloadRequests(
      model: model,
      wikiUrl: _wiki?.result.url,
      wikiBytes: _wiki?.result.sizeBytes,
    );
    final sink = widget.enqueue ?? _realEnqueue;
    for (final r in reqs) {
      sink(r);
    }
    Navigator.of(context).pop();
    // El progreso vive en Depósito → Descargas (pestaña 4): UI ya existente.
    (widget.onGoDownloads ?? () => ShellNav.goDepot(tab: 4))();
  }

  void _pickMap() {
    Navigator.of(context).pop();
    (widget.onGoMaps ?? ShellNav.goMaps)();
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'setupTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr(context, 'setupIntro')),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: Text(tr(context, 'setupAiTitle')),
              subtitle: Text(model == null
                  ? tr(context, 'setupAiSubtitle')
                  : '${modelDisplayName(model.fileName)} · '
                      '${humanSize(model.sizeBytes)}\n'
                      '${tr(context, 'setupAiSubtitle')}'),
              isThreeLine: model != null,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(tr(context, 'setupWikiTitle')),
              subtitle: Text(_wikiLoading
                  ? tr(context, 'setupWikiSearching')
                  : _wiki == null
                      ? tr(context, 'setupWikiOffline')
                      : '${_wiki!.result.title}'
                          '${_wiki!.result.sizeBytes != null ? ' · ${humanSize(_wiki!.result.sizeBytes!)}' : ''}'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(_region == null
                  ? tr(context, 'setupMapTitle')
                  : '${_region!.flag} ${_region!.name}'),
              subtitle: _region == null ? null : Text('~${_region!.sizeMB} MB'),
              trailing: TextButton(
                onPressed: _pickMap,
                child: Text(tr(context, 'setupMapPick')),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: model == null ? null : _downloadAll,
            icon: const Icon(Icons.download),
            label: Text(
                '${tr(context, 'setupDownloadAll')} (${humanSize(_totalBytes)})'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr(context, 'setupSkip')),
          ),
        ],
      ),
    );
  }
}
