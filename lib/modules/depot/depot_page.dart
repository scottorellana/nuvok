import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/build_flags.dart';
import '../../core/nuvok_library.dart';
import '../update/update_page.dart';
import 'download_manager.dart';
import 'app_share_page.dart';
import 'kiwix_catalog.dart';
import 'map_catalog.dart';
import 'starter_pack.dart';
import '../../core/locale_service.dart';

class DepotPage extends StatefulWidget {
  const DepotPage({super.key, this.initialTab = 0});
  final int initialTab;

  /// Whether the in-app update tab exists in this build. Store builds never
  /// self-update (Apple 2.5.2 / Play policy — the stores own updates), and on
  /// iOS there is no sideload channel at all, so the tab never applies there.
  static bool showUpdatesTab({required bool storeBuild, required bool isIOS}) =>
      !storeBuild && !isIOS;

  static bool get _updatesTabEnabled =>
      showUpdatesTab(storeBuild: kStoreBuild, isIOS: Platform.isIOS);

  @override
  State<DepotPage> createState() => _DepotPageState();
}

class _DepotPageState extends State<DepotPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
      length: DepotPage._updatesTabEnabled ? 6 : 5,
      vsync: this,
      initialIndex: widget.initialTab);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'depot')),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Semantics(
              label: 'Pestaña Esenciales',
              child: Tab(
                  text: tr(context, 'essentials'),
                  icon: Icon(Icons.medical_services, size: 18)),
            ),
            Semantics(
              label: 'Pestaña Biblioteca',
              child: Tab(
                  text: tr(context, 'library'), icon: Icon(Icons.menu_book, size: 18)),
            ),
            Semantics(
              label: 'Pestaña Modelos IA',
              child: Tab(
                  text: tr(context, 'aiModels'), icon: Icon(Icons.psychology, size: 18)),
            ),
            Semantics(
              label: 'Pestaña Mapas',
              child: Tab(text: tr(context, 'maps'), icon: Icon(Icons.map, size: 18)),
            ),
            Semantics(
              label: 'Pestaña Descargas',
              child:
                  Tab(text: tr(context, 'downloads'), icon: Icon(Icons.download, size: 18)),
            ),
            if (DepotPage._updatesTabEnabled)
              Semantics(
                label: 'Pestaña App',
                child:
                    Tab(text: tr(context, 'appTab'), icon: Icon(Icons.system_update, size: 18)),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const _StarterPackTab(),
          const _ZimCatalogTab(),
          const _ModelsTab(),
          const _MapsInstallTab(),
          const _DownloadsTab(),
          if (DepotPage._updatesTabEnabled) const UpdatePage(),
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
        '${NuvokLibrary.instance.zimDir.path}/$fileName',
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
                    child: Text('Paquetes de contenido offline',
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
                'Primeros auxilios, supervivencia, agua, desastres y alimentos. '
                'Con internet se descargan directo desde Nuvok; después '
                'quedan disponibles sin conexión.',
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
                              leading:
                                  const Icon(Icons.health_and_safety, size: 32),
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
                                    '${NuvokLibrary.instance.zimDir.path}/${Uri.parse(c.result.url).pathSegments.last}',
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
                              label: const Text('Descargar todos los paquetes'),
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
        setState(() =>
            _error = 'Sin conexión a internet. El catálogo necesita conexión '
                'solo para descargar contenido nuevo — lo ya '
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
    final dest = '${NuvokLibrary.instance.zimDir.path}/$fileName';
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
// Curated AI models — with install detection and rich metadata
// ---------------------------------------------------------------------------

class _ModelsTab extends StatefulWidget {
  const _ModelsTab();

  @override
  State<_ModelsTab> createState() => _ModelsTabState();
}

class _ModelsTabState extends State<_ModelsTab> {
  final _manager = DownloadManager.instance;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final installedFiles = NuvokLibrary.instance.listModels();
    final installedNames =
        installedFiles.map((f) => f.path.split('/').last).toSet();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.share),
            title: Text(tr(context, 'shareAppTitle')),
            subtitle: Text(tr(context, 'shareAppIntro'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const AppSharePage(),
            )),
          ),
        ),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.psychology, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Modelos de IA descargables',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (installedFiles.isNotEmpty)
                  Chip(
                    label: Text('${installedFiles.length} instalados'),
                    avatar: const Icon(Icons.check_circle, size: 18),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Estos modelos se ejecutan localmente en tu dispositivo. '
            'Una vez descargados, funcionan 100% sin internet. '
            'Elige según la RAM disponible:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        for (final m in curatedModels)
          _ModelCard(
            model: m,
            isInstalled: installedNames.contains(m.fileName),
            isDownloading: _manager.isDownloading(m.url),
          ),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.isInstalled,
    required this.isDownloading,
  });

  final CuratedModel model;
  final bool isInstalled;
  final bool isDownloading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destPath =
        '${NuvokLibrary.instance.modelsDir.path}/${model.fileName}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_outlined,
                    color:
                        model.recommended ? theme.colorScheme.primary : null),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    model.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (model.recommended)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '★ Recomendado',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                if (isInstalled)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Instalado',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(model.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _InfoChip(
                  icon: Icons.memory,
                  label: '~${humanSize(model.approxBytes)}',
                ),
                if (model.minRamGb != null)
                  _InfoChip(
                    icon: Icons.developer_board,
                    label: '${model.minRamGb}GB RAM min.',
                  ),
                _InfoChip(
                  icon: Icons.language,
                  label: model.languages.join(', '),
                ),
                for (final tag in model.tags)
                  _InfoChip(
                      label: tag, color: theme.colorScheme.secondaryContainer),
              ],
            ),
            const SizedBox(height: 12),
            if (isInstalled)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.chat),
                  label: const Text('Abrir en Asistente IA'),
                ),
              )
            else if (isDownloading)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _DownloadProgress(url: model.url),
              )
            else
              SizedBox(
                width: double.infinity,
                child: _DownloadButton(
                  url: model.url,
                  destPath: destPath,
                  totalBytes: model.approxBytes,
                  label: 'Descargar',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({this.icon, required this.label, this.color});
  final IconData? icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Theme.of(context).hintColor),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final task = DownloadManager.instance.taskFor(url);
    if (task == null) return const SizedBox.shrink();
    final pct = task.totalBytes != null && task.totalBytes! > 0
        ? (task.received / task.totalBytes! * 100).clamp(0, 100)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              pct != null
                  ? 'Descargando… ${pct.toStringAsFixed(0)}%'
                  : 'Descargando… ${humanSize(task.received)}',
              style: const TextStyle(fontSize: 13),
            ),
            const Spacer(),
            Text(
              task.totalBytes != null
                  ? '${humanSize(task.received)} / ${humanSize(task.totalBytes!)}'
                  : humanSize(task.received),
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ],
        ),
        if (pct != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Maps installer
// ---------------------------------------------------------------------------

class _MapsInstallTab extends StatefulWidget {
  const _MapsInstallTab();

  @override
  State<_MapsInstallTab> createState() => _MapsInstallTabState();
}

class _MapsInstallTabState extends State<_MapsInstallTab> {
  List<MapRegion> _regions = [];
  bool _loading = true;
  String _filter = '';
  // Region id currently being extracted → last progress line.
  final Map<String, String> _extracting = {};
  final _manager = DownloadManager.instance;

  @override
  void initState() {
    super.initState();
    MapCatalog.load().then((r) {
      if (mounted) {
        setState(() {
          _regions = r;
          _loading = false;
        });
      }
    });
    _manager.addListener(_onDownloads);
  }

  @override
  void dispose() {
    _manager.removeListener(_onDownloads);
    super.dispose();
  }

  void _onDownloads() {
    if (mounted) setState(() {});
  }

  Future<void> _extract(MapRegion region) async {
    setState(() => _extracting[region.id] = 'Preparando…');
    await for (final line in MapExtractor.extract(region)) {
      if (!mounted) return;
      setState(() => _extracting[region.id] = line);
    }
    if (!mounted) return;
    final last = _extracting[region.id] ?? '';
    setState(() => _extracting.remove(region.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(last.startsWith('error')
          ? '❌ ${region.name}: $last'
          : '✅ Mapa de ${region.name} instalado. Ábrelo en Mapas.'),
      duration: const Duration(seconds: 5),
    ));
  }

  Future<void> _downloadUrl([String? preset]) async {
    final txt = TextEditingController(text: preset ?? '');
    final dialogWidth =
        (MediaQuery.of(context).size.width - 48).clamp(320.0, 480.0).toDouble();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descargar mapa por URL'),
        content: SizedBox(
          width: dialogWidth,
          child: TextField(
            controller: txt,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'URL directa a un archivo .pmtiles',
              hintText: 'https://…/mi-region.pmtiles',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, txt.text.trim()),
              child: const Text('Descargar')),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;
    if (!url.startsWith('http') || !url.contains('.pmtiles')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La URL debe apuntar a un archivo .pmtiles')));
      return;
    }
    final name = Uri.parse(url).pathSegments.last;
    _manager.enqueue(url, '${NuvokLibrary.instance.mapsDir.path}/$name');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Descargando $name — mira la pestaña Descargas')));
  }

  /// Lists and downloads maps from the Nuvok server running on the same
  /// WiFi (installer-server). No internet needed — this is how a phone/tablet
  /// gets maps that a nearby computer prepared. Works even where on-device
  /// extraction isn't available (Android has no pmtiles CLI).
  Future<void> _localServerMaps() async {
    final saved = NuvokLibrary.instance.settings['localMapServer'] as String?;
    final ctrl = TextEditingController(text: saved ?? 'http://');
    final localServerWidth =
        (MediaQuery.of(context).size.width - 48).clamp(320.0, 480.0).toDouble();
    final base = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Servidor local de mapas'),
        content: SizedBox(
          width: localServerWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Escribe la dirección que muestra el instalador de Nuvok '
                'Pad en la computadora de tu red (misma WiFi). Descarga '
                'mapas sin internet.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'http://192.168.x.x:8848',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Conectar')),
        ],
      ),
    );
    if (base == null || base.isEmpty || base == 'http://' || !mounted) return;
    final baseUrl = base.replaceAll(RegExp(r'/+$'), '');
    await NuvokLibrary.instance.saveSetting('localMapServer', baseUrl);

    List<dynamic> maps;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse('$baseUrl/api/content'));
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join();
      client.close();
      final list = jsonDecode(body) as List<dynamic>;
      maps = [
        for (final e in list)
          if ((e as Map)['type'] == 'maps') e,
      ];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo conectar a $baseUrl. '
                '¿Están en la misma WiFi y el servidor encendido?')));
      }
      return;
    }
    if (!mounted) return;
    if (maps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('El servidor no tiene mapas. Extrae uno en la computadora '
                  'primero (queda en la carpeta Nuvok/maps).')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mapas en el servidor'),
        content: SizedBox(
          width: localServerWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in maps)
                ListTile(
                  leading: const Text('🗺️', style: TextStyle(fontSize: 22)),
                  title: Text((m as Map)['name'] as String),
                  subtitle: Text(_fmtBytes((m['size'] as num?)?.toInt() ?? 0)),
                  trailing: const Icon(Icons.download),
                  onTap: () {
                    final name = m['name'] as String;
                    final url = '$baseUrl${m['url']}';
                    _manager.enqueue(
                        url, '${NuvokLibrary.instance.mapsDir.path}/$name');
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Descargando $name — mira la pestaña Descargas')));
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  static String _fmtBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var u = 0;
    while (size >= 1024 && u < units.length - 1) {
      size /= 1024;
      u++;
    }
    return '${size.toStringAsFixed(size < 10 && u > 0 ? 1 : 0)} ${units[u]}';
  }

  Future<void> _importLocal() async {
    const typeGroup =
        XTypeGroup(label: 'Mapas PMTiles', extensions: ['pmtiles']);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null || !mounted) return;
    final dest = '${NuvokLibrary.instance.mapsDir.path}/${file.name}';
    setState(() => _extracting['_import'] = 'Copiando ${file.name}…');
    try {
      // Copy through a .part so the Maps module never sees a half file.
      await File(file.path).copy('$dest.part');
      File('$dest.part').renameSync(dest);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ ${file.name} importado. Ábrelo en Mapas.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo importar: $e')));
      }
    } finally {
      if (mounted) setState(() => _extracting.remove('_import'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final canExtract = MapExtractor.available;

    // Filter by name, then group by continent preserving catalog order.
    final q = _filter.trim().toLowerCase();
    final shown = q.isEmpty
        ? _regions
        : _regions.where((r) => r.name.toLowerCase().contains(q)).toList();
    final groups = <String, List<MapRegion>>{};
    for (final r in shown) {
      groups.putIfAbsent(r.group, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Instalar mapas offline',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        // Wrap (not Row) so the actions never overflow on a narrow phone.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // The key path for phones/tablets: pull ready maps from the
            // Nuvok server on the same WiFi — no internet, one tap.
            FilledButton.tonalIcon(
              onPressed: _localServerMaps,
              icon: const Icon(Icons.lan, size: 18),
              label: const Text('Servidor local'),
            ),
            if (canExtract)
              OutlinedButton.icon(
                onPressed: _customRegion,
                icon: const Icon(Icons.public, size: 18),
                label: const Text('Región personalizada'),
              ),
            OutlinedButton.icon(
              onPressed: _importLocal,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Importar'),
            ),
            OutlinedButton.icon(
              onPressed: () => _downloadUrl(),
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Por URL'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          canExtract
              ? 'Elige un país (un toque y se recorta del mapa mundial de '
                  'Protomaps) o usa "Región personalizada" para cualquier '
                  'área del mundo. Solo se usa internet al instalar.'
              : 'En este dispositivo no se recortan mapas. Usa "Servidor '
                  'local" para bajar los mapas listos desde una computadora '
                  'con Nuvok en tu WiFi (sin internet), o "Por URL" / '
                  '"Importar" un .pmtiles.',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar país (ej: España, México, Japón…)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'Sin coincidencias. Prueba "Región personalizada" '
                'para cualquier zona del mundo.',
                style: TextStyle(color: Colors.grey)),
          ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(entry.key,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          for (final r in entry.value) _regionCard(r, canExtract),
        ],
        const SizedBox(height: 12),
        Text(
          'Carpeta de mapas: ${NuvokLibrary.instance.mapsDir.path}\n'
          'Datos de mapa © OpenStreetMap contributors (ODbL) · '
          'tiles por Protomaps.',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _regionCard(MapRegion r, bool canExtract) {
    final zoomNote = r.maxZoom != null ? ' · detalle medio' : '';
    return Card(
      child: ListTile(
        leading: Text(r.flag, style: const TextStyle(fontSize: 28)),
        title: Text(r.name),
        subtitle: Text(
          _extracting.containsKey(r.id)
              ? _extracting[r.id]!
              : r.installed
                  ? 'Instalado ✓'
                  : '~${r.sizeMB} MB$zoomNote',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: r.installed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : _extracting.containsKey(r.id)
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : r.url != null
                    ? FilledButton.icon(
                        onPressed: () {
                          _manager.enqueue(r.url!,
                              '${NuvokLibrary.instance.mapsDir.path}/${r.fileName}');
                          setState(() {});
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Descargar'),
                      )
                    : canExtract && r.bbox != null
                        ? FilledButton.icon(
                            onPressed: () => _extract(r),
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Instalar'),
                          )
                        : const Tooltip(
                            message: 'Usa "Por URL" o "Importar" en este '
                                'dispositivo',
                            child: Icon(Icons.info_outline),
                          ),
      ),
    );
  }

  /// Lets the user extract ANY area of the world by bounding box.
  Future<void> _customRegion() async {
    final nameCtrl = TextEditingController();
    final bboxCtrl = TextEditingController();
    final regionDialogWidth =
        (MediaQuery.of(context).size.width - 48).clamp(320.0, 520.0).toDouble();
    final region = await showDialog<MapRegion>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Región personalizada'),
        content: SizedBox(
          width: regionDialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nombre (ej: Mi ciudad, Región X)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bboxCtrl,
                decoration: const InputDecoration(
                  labelText: 'Área: oesteLon,surLat,esteLon,norteLat',
                  hintText: '-89.36,12.98,-83.13,17.42',
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Consejo: en bboxfinder.com dibujas un rectángulo en el '
                  'mapa y te da esos 4 números. Cuanto más grande el área, '
                  'más pesa y tarda.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final bbox = bboxCtrl.text.trim();
              final parts = bbox.split(',');
              final valid = parts.length == 4 &&
                  parts.every((p) => double.tryParse(p.trim()) != null);
              if (name.isEmpty || !valid) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Escribe un nombre y 4 números separados '
                        'por comas.')));
                return;
              }
              final id =
                  'custom-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
              Navigator.pop(
                  context,
                  MapRegion(
                    id: id,
                    name: name,
                    flag: '📍',
                    group: 'Personalizadas',
                    sizeMB: 0,
                    bbox: parts.map((p) => p.trim()).join(','),
                  ));
            },
            child: const Text('Instalar'),
          ),
        ],
      ),
    );
    if (region != null) await _extract(region);
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
    this.label,
  });

  final String url;
  final String destPath;
  final int? totalBytes;
  final String? label;

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
    final task =
        _manager.tasks.where((t) => t.destPath == widget.destPath).lastOrNull;
    if (task != null && task.status == DownloadStatus.downloading) {
      // Full-width button variant shows progress inline
      if (widget.label != null) {
        return SizedBox(
          width: double.infinity,
          child: LinearProgressIndicator(value: task.progress, minHeight: 6),
        );
      }
      return SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(value: task.progress, strokeWidth: 3),
      );
    }
    if (task != null && task.status == DownloadStatus.queued) {
      if (widget.label != null) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: null,
            icon: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            label: const Text('En cola…'),
          ),
        );
      }
      return const Icon(Icons.schedule);
    }

    void startDownload() => _manager.enqueue(
          widget.url,
          widget.destPath,
          totalBytes: widget.totalBytes,
        );

    if (widget.label != null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: startDownload,
          icon: const Icon(Icons.download),
          label: Text(widget.label!),
        ),
      );
    }
    return IconButton(
      tooltip: 'Descargar',
      icon: const Icon(Icons.download),
      onPressed: startDownload,
    );
  }
}
