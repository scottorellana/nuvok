import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../zim/zim_content_server.dart';
import '../../zim/zim_file.dart';
import 'zim_web_reader_page.dart';

/// Chooses the best reader for the platform: the native WebView reader
/// (video/audio/JS) where available, or the lightweight pure-Flutter
/// renderer on Linux/Raspberry Pi where no stable WebView exists yet.
class ZimReaderPage extends StatelessWidget {
  const ZimReaderPage({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) return ZimClassicReaderPage(path: path);
    return ZimWebReaderPage(path: path);
  }
}

class ZimClassicReaderPage extends StatefulWidget {
  const ZimClassicReaderPage({super.key, required this.path});
  final String path;

  @override
  State<ZimClassicReaderPage> createState() => _ZimClassicReaderPageState();
}

class _ZimClassicReaderPageState extends State<ZimClassicReaderPage> {
  ZimFile? _zim;
  String? _error;
  String? _bookTitle;

  // Navigation history of full ZIM paths (e.g. "C/A/San_Francisco").
  final List<String> _history = [];
  String? _currentPath;
  String? _html;
  bool _loadingArticle = false;

  // Search
  final _searchController = TextEditingController();
  List<ZimSearchResult> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    final zim = _zim;
    if (zim != null) {
      ZimContentServer.instance.release(zim);
      zim.close();
    }
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final zim = await ZimFile.open(widget.path);
      _zim = zim;
      _bookTitle = await zim.metadata('Title');
      // The content server lets "Ver en el navegador" play videos on
      // platforms without an embedded WebView (Linux/Raspberry Pi).
      await ZimContentServer.instance.serve(zim);
      final main = await zim.mainPage();
      if (main != null) {
        await _navigateTo(main.fullPath, pushHistory: false);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Opens the current article in the system browser, where video and audio
  /// play natively. Content still comes from the internal offline server.
  Future<void> _openInBrowser() async {
    final zim = _zim;
    final path = _currentPath;
    if (zim == null || path == null) return;
    final url = ZimContentServer.instance.urlFor(zim, path).toString();
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      }
    } catch (_) {
      _showSnack('No se pudo abrir el navegador');
    }
  }

  Future<void> _navigateTo(String fullPath, {bool pushHistory = true}) async {
    final zim = _zim;
    if (zim == null) return;
    setState(() => _loadingArticle = true);
    try {
      var blob = await zim.contentAtPath(fullPath);
      if (blob == null) {
        // Some links omit the namespace; try content namespace variants.
        for (final candidate in ['C/$fullPath', 'A/$fullPath']) {
          blob = await zim.contentAtPath(candidate);
          if (blob != null) {
            fullPath = candidate;
            break;
          }
        }
      }
      final found = blob;
      if (found == null) {
        _showSnack('No se encontró: $fullPath');
        return;
      }
      if (!found.mimeType.startsWith('text/html')) {
        _showSnack('Tipo de contenido no legible: ${found.mimeType}');
        return;
      }
      if (pushHistory && _currentPath != null) _history.add(_currentPath!);
      setState(() {
        _currentPath = fullPath;
        _html = utf8.decode(found.data, allowMalformed: true);
        _suggestions = [];
        _searchController.clear();
      });
    } finally {
      if (mounted) setState(() => _loadingArticle = false);
    }
  }

  void _goBack() {
    if (_history.isEmpty) return;
    final prev = _history.removeLast();
    _navigateTo(prev, pushHistory: false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final zim = _zim;
      if (zim == null || text.trim().isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      final results = await zim.suggest(text.trim(), limit: 12);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  /// Resolves a relative href/src against the current article path.
  String? _resolve(String href) {
    if (href.startsWith('http://') ||
        href.startsWith('https://') ||
        href.startsWith('mailto:')) {
      return null; // external link — not available offline
    }
    var h = href.split('#').first.split('?').first;
    if (h.isEmpty) return null;
    h = Uri.decodeComponent(h);
    final current = _currentPath ?? '';
    final ns = current.isNotEmpty ? current[0] : 'C';
    if (h.startsWith('/')) return '$ns${h.startsWith('/') ? h : '/$h'}';
    // Relative resolution within the namespace.
    final currentUrl = current.length > 2 ? current.substring(2) : '';
    final baseSegments = currentUrl.split('/')
      ..removeLast(); // directory of current article
    final segments = [...baseSegments, ...h.split('/')];
    final out = <String>[];
    for (final s in segments) {
      if (s == '.' || s.isEmpty) continue;
      if (s == '..') {
        if (out.isNotEmpty) out.removeLast();
      } else {
        out.add(s);
      }
    }
    return '$ns/${out.join('/')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No se pudo abrir el archivo:\n$_error',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Si el libro se estaba descargando, espera a que termine '
                'la descarga y reintenta.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _error = null);
                  _open();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () {
          if (_history.isNotEmpty) {
            _goBack();
          } else {
            Navigator.of(context).pop();
          }
        }),
        title: Text(_bookTitle ?? 'Lectura'),
        actions: [
          IconButton(
            tooltip: 'Ver con videos en el navegador',
            icon: const Icon(Icons.ondemand_video_outlined),
            onPressed: _openInBrowser,
          ),
          IconButton(
            tooltip: 'Página principal',
            icon: const Icon(Icons.home_outlined),
            onPressed: () async {
              final main = await _zim?.mainPage();
              if (main != null) _navigateTo(main.fullPath);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar artículos…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_html != null)
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HtmlWidget(
                _html!,
                renderMode: RenderMode.column,
                onTapUrl: (url) {
                  final resolved = _resolve(url);
                  if (resolved == null) {
                    _showSnack('Enlace externo — no disponible sin internet');
                    return true;
                  }
                  _navigateTo(resolved);
                  return true;
                },
                customWidgetBuilder: (element) {
                  if (element.localName == 'img') {
                    final src = element.attributes['src'];
                    if (src == null) return null;
                    final resolved = _resolve(src);
                    if (resolved == null) return const SizedBox.shrink();
                    return _ZimImage(zim: _zim!, path: resolved);
                  }
                  return null;
                },
              ),
            )
          else if (!_loadingArticle)
            const Center(child: Text('Busca un artículo para empezar')),
          if (_loadingArticle) const Center(child: CircularProgressIndicator()),
          if (_suggestions.isNotEmpty)
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: Card(
                elevation: 8,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in _suggestions)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.article_outlined, size: 18),
                        title: Text(s.title),
                        onTap: () => _navigateTo(s.entry.fullPath),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZimImage extends StatelessWidget {
  const _ZimImage({required this.zim, required this.path});
  final ZimFile zim;
  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ZimBlob?>(
      future: zim.contentAtPath(path),
      builder: (context, snapshot) {
        final blob = snapshot.data;
        if (blob == null) return const SizedBox.shrink();
        if (blob.mimeType.contains('svg')) return const SizedBox.shrink();
        return Image.memory(blob.data, errorBuilder: (_, __, ___) {
          return const SizedBox.shrink();
        });
      },
    );
  }
}
