import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/prepper_library.dart';
import 'download_manager.dart';
import 'kiwix_catalog.dart';
import 'starter_pack.dart';

class DepotPage extends StatefulWidget {
  const DepotPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<DepotPage> createState() => _DepotPageState();
}

class _DepotPageState extends State<DepotPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 5, vsync: this, initialIndex: widget.initialTab);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Depósito'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Esenciales', icon: Icon(Icons.medical_services, size: 18)),
            Tab(text: 'Biblioteca', icon: Icon(Icons.menu_book, size: 18)),
            Tab(text: 'Modelos IA', icon: Icon(Icons.psychology, size: 18)),
            Tab(text: 'Mapas', icon: Icon(Icons.map, size: 18)),
            Tab(text: 'Descargas', icon: Icon(Icons.download, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _StarterPackTab(),
          _ZimCatalogTab(),
          _ModelsTab(),
          _MapsHelpTab(),
          _DownloadsTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Starter pack: first-aid + survival manuals matched to the user's language
// ---------------------------------------------------------------------------

class _StarterPackTab extends StatefulWidget {
  const _StarterPackTab();

  @override
  State<_StarterPackTab> createState() => _StarterPackTabState();
}

class _StarterPackTabState extends State<_StarterPackTab>
    with AutomaticKeepAliveClientMixin {
  List<StarterCandidate>? _candidates;
  String? _error;
  bool _loading = false;
  late String _lang = StarterPack.systemLang();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await StarterPack.resolve(lang: _lang);
      if (mounted) setState(() => _candidates = c);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Estos manuales se descargan una vez con internet. Sin conexión '
            'no se pueden obtener ahora, pero lo que ya tengas descargado '
            'sigue disponible.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _downloadAll() {
    for (final c in _candidates ?? <StarterCandidate>[]) {
      final fileName = Uri.parse(c.result.url).pathSegments.last;
      DownloadManager.instance.enqueue(
        c.result.url,
        '${PrepperLibrary.instance.zimDir.path}/$fileName',
        totalBytes: c.result.sizeBytes,
      );
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Descargas encoladas — mira la pestaña "Descargas"'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Paquete inicial de emergencia',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  DropdownButton<String>(
                    value: _lang,
                    items: const [
                      DropdownMenuItem(value: 'spa', child: Text('Español')),
                      DropdownMenuItem(value: 'eng', child: Text('English')),
                      DropdownMenuItem(value: 'fra', child: Text('Français')),
                      DropdownMenuItem(value: 'por', child: Text('Português')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _lang = v);
                        _resolve();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Manuales de primeros auxilios y supervivencia en el idioma '
                'seleccionado. Descárgalos una vez y quedan disponibles para '
                'siempre sin internet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off, size: 56),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _resolve,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (final c in _candidates ?? <StarterCandidate>[])
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.health_and_safety,
                                  size: 32),
                              title: Text(c.item.category),
                              subtitle: Text(
                                '${c.item.description}\n'
                                '${c.result.title}'
                                '${c.result.sizeBytes != null ? ' · ${humanSize(c.result.sizeBytes!)}' : ''}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              trailing: _DownloadButton(
                                url: c.result.url,
                                destPath:
                                    '${PrepperLibrary.instance.zimDir.path}/${Uri.parse(c.result.url).pathSegments.last}',
                                totalBytes: c.result.sizeBytes,
                              ),
                            ),
                          ),
                        if ((_candidates ?? []).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: FilledButton.icon(
                              onPressed: _downloadAll,
                              icon: const Icon(Icons.download),
                              label: const Text('Descargar todo el paquete'),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ZIM catalog (Kiwix OPDS)
// ---------------------------------------------------------------------------

class _ZimCatalogTab extends StatefulWidget {
  const _ZimCatalogTab();

  @override
  State<_ZimCatalogTab> createState() => _ZimCatalogTabState();
}

class _ZimCatalogTabState extends State<_ZimCatalogTab>
    with AutomaticKeepAliveClientMixin {
  final _query = TextEditingController();
  String _lang = 'spa';
  List<CatalogItem>? _items;
  String? _error;
  bool _loading = false;
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await KiwixCatalog.search(
        query: _query.text.trim(),
        lang: _lang,
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Sin conexión a internet. El catálogo necesita conexión '
            'solo para descargar contenido nuevo — todo lo ya '
            'descargado sigue disponible.\n\n($e)');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce =
                        Timer(const Duration(milliseconds: 500), _search);
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar: wikipedia, medicina, supervivencia…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _lang,
                items: const [
                  DropdownMenuItem(value: 'spa', child: Text('Español')),
                  DropdownMenuItem(value: 'eng', child: Text('English')),
                  DropdownMenuItem(value: '', child: Text('Todos')),
                ],
                onChanged: (v) {
                  setState(() => _lang = v ?? '');
                  _search();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off, size: 56),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _search,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final item in _items ?? <CatalogItem>[])
                          _CatalogTile(item: item),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final fileName = Uri.parse(item.url).pathSegments.last;
    final dest = '${PrepperLibrary.instance.zimDir.path}/$fileName';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(item.title),
        subtitle: Text(
          '${item.summary}\n'
          '${item.sizeBytes != null ? humanSize(item.sizeBytes!) : 'Tamaño desconocido'}'
          '${item.language != null ? ' · ${item.language}' : ''}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: _DownloadButton(
          url: item.url,
          destPath: dest,
          totalBytes: item.sizeBytes,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Curated AI models
// ---------------------------------------------------------------------------

class _ModelsTab extends StatelessWidget {
  const _ModelsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Modelos seleccionados para hardware modesto. Una vez '
            'descargados funcionan 100% sin internet.',
          ),
        ),
        for (final m in curatedModels)
          Card(
            child: ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: Text(m.name),
              subtitle:
                  Text('${m.description}\n~${humanSize(m.approxBytes)}'),
              isThreeLine: true,
              trailing: _DownloadButton(
                url: m.url,
                destPath:
                    '${PrepperLibrary.instance.modelsDir.path}/${Uri.parse(m.url).pathSegments.last}',
                totalBytes: null,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Maps guidance
// ---------------------------------------------------------------------------

class _MapsHelpTab extends StatelessWidget {
  const _MapsHelpTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mapas offline (.pmtiles)',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const Text(
                '1. Entra a maps.protomaps.com/builds (con internet).\n\n'
                '2. Descarga el mapa del mundo completo, o usa la '
                'herramienta "pmtiles extract" para recortar tu país o '
                'región (mucho más ligero).\n\n'
                '3. Copia el archivo .pmtiles a la carpeta de mapas de tu '
                'biblioteca:',
              ),
              const SizedBox(height: 8),
              SelectableText(
                PrepperLibrary.instance.mapsDir.path,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                '4. Abre el módulo Mapas — tu región aparecerá lista para '
                'usar sin conexión.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Downloads
// ---------------------------------------------------------------------------

class _DownloadsTab extends StatefulWidget {
  const _DownloadsTab();

  @override
  State<_DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<_DownloadsTab> {
  final _manager = DownloadManager.instance;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onChange);
  }

  @override
  void dispose() {
    _manager.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _manager.tasks;
    if (tasks.isEmpty) {
      return const Center(child: Text('No hay descargas'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final t in tasks)
          Card(
            child: ListTile(
              leading: Icon(switch (t.status) {
                DownloadStatus.done => Icons.check_circle,
                DownloadStatus.error => Icons.error_outline,
                DownloadStatus.downloading => Icons.downloading,
                _ => Icons.schedule,
              }),
              title: Text(t.fileName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t.status == DownloadStatus.downloading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: LinearProgressIndicator(value: t.progress),
                    ),
                  Text(t.status == DownloadStatus.error
                      ? (t.error ?? 'Error')
                      : '${humanSize(t.received)}'
                          '${t.totalBytes != null ? ' / ${humanSize(t.totalBytes!)}' : ''}'),
                ],
              ),
              trailing: t.status == DownloadStatus.error
                  ? IconButton(
                      tooltip: 'Reanudar',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _manager.retry(t),
                    )
                  : t.status == DownloadStatus.done
                      ? null
                      : IconButton(
                          tooltip: 'Cancelar',
                          icon: const Icon(Icons.close),
                          onPressed: () => _manager.remove(t),
                        ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _DownloadButton extends StatefulWidget {
  const _DownloadButton({
    required this.url,
    required this.destPath,
    this.totalBytes,
  });

  final String url;
  final String destPath;
  final int? totalBytes;

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  final _manager = DownloadManager.instance;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onChange);
  }

  @override
  void dispose() {
    _manager.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final exists = File(widget.destPath).existsSync();
    if (exists) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    final task = _manager.tasks
        .where((t) => t.destPath == widget.destPath)
        .lastOrNull;
    if (task != null && task.status == DownloadStatus.downloading) {
      return SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(value: task.progress, strokeWidth: 3),
      );
    }
    if (task != null && task.status == DownloadStatus.queued) {
      return const Icon(Icons.schedule);
    }
    return IconButton(
      tooltip: 'Descargar',
      icon: const Icon(Icons.download),
      onPressed: () => _manager.enqueue(
        widget.url,
        widget.destPath,
        totalBytes: widget.totalBytes,
      ),
    );
  }
}
