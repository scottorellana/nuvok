import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../zim/zim_content_server.dart';
import '../../zim/zim_file.dart';

/// Full-fidelity ZIM reader: a native WebView fed by the internal loopback
/// content server. Plays video/audio (TED, TEDx, podcasts) and runs the
/// JavaScript that media-heavy ZIMs need. Used on macOS/Windows/Android;
/// Linux falls back to the lightweight renderer.
class ZimWebReaderPage extends StatefulWidget {
  const ZimWebReaderPage({super.key, required this.path});
  final String path;

  @override
  State<ZimWebReaderPage> createState() => _ZimWebReaderPageState();
}

class _ZimWebReaderPageState extends State<ZimWebReaderPage> {
  ZimFile? _zim;
  String? _error;
  String? _bookTitle;
  Uri? _homeUrl;
  InAppWebViewController? _controller;

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
      final home = await ZimContentServer.instance.serve(zim);
      if (home == null) {
        throw ZimException('El archivo no tiene página principal');
      }
      if (mounted) setState(() => _homeUrl = home);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
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

  Future<void> _goTo(String zimPath) async {
    final zim = _zim;
    final controller = _controller;
    if (zim == null || controller == null) return;
    setState(() {
      _suggestions = [];
      _searchController.clear();
    });
    await controller.loadUrl(
      urlRequest: URLRequest(
        url: WebUri.uri(ZimContentServer.instance.urlFor(zim, zimPath)),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        leading: BackButton(onPressed: () async {
          final navigator = Navigator.of(context);
          final controller = _controller;
          if (controller != null && await controller.canGoBack()) {
            await controller.goBack();
          } else {
            navigator.pop();
          }
        }),
        title: Text(_bookTitle ?? 'Lectura'),
        actions: [
          IconButton(
            tooltip: 'Página principal',
            icon: const Icon(Icons.home_outlined),
            onPressed: () async {
              final home = _homeUrl;
              if (home != null) {
                await _controller?.loadUrl(
                    urlRequest: URLRequest(url: WebUri.uri(home)));
              }
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
          if (_homeUrl == null)
            const Center(child: CircularProgressIndicator())
          else
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri.uri(_homeUrl!)),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                isInspectable: false,
              ),
              onWebViewCreated: (c) => _controller = c,
              shouldOverrideUrlLoading: (controller, action) async {
                final url = action.request.url;
                if (url == null) return NavigationActionPolicy.CANCEL;
                if (url.host == '127.0.0.1' || url.scheme == 'about') {
                  return NavigationActionPolicy.ALLOW;
                }
                _showSnack(
                    'Enlace externo — no disponible sin internet: $url');
                return NavigationActionPolicy.CANCEL;
              },
            ),
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
                        leading:
                            const Icon(Icons.article_outlined, size: 18),
                        title: Text(s.title),
                        onTap: () => _goTo(s.entry.fullPath),
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
