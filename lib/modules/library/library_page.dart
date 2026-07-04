import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/prepper_library.dart';
import '../../zim/zim_file.dart';
import '../depot/download_manager.dart';
import 'zim_reader_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _ZimCardInfo {
  _ZimCardInfo(this.file,
      {this.title, this.description, this.icon, this.error});
  final File file;
  final String? title;
  final String? description;
  final Uint8List? icon;
  final String? error;
}

class _LibraryPageState extends State<LibraryPage> {
  List<_ZimCardInfo>? _zims;
  int _lastDoneDownloads = -1;

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh automatically when the Depot finishes a download, so a book
    // that just arrived opens without hunting for the refresh button.
    DownloadManager.instance.addListener(_onDownloadsChanged);
  }

  @override
  void dispose() {
    DownloadManager.instance.removeListener(_onDownloadsChanged);
    super.dispose();
  }

  void _onDownloadsChanged() {
    final done = DownloadManager.instance.tasks
        .where((t) => t.status == DownloadStatus.done)
        .length;
    if (done != _lastDoneDownloads) {
      _lastDoneDownloads = done;
      if (mounted) _load();
    }
  }

  Future<void> _load() async {
    final files = PrepperLibrary.instance.listZims();
    final infos = <_ZimCardInfo>[];
    for (final f in files) {
      try {
        final zim = await ZimFile.open(f.path);
        infos.add(_ZimCardInfo(
          f,
          title: await zim.metadata('Title'),
          description: await zim.metadata('Description'),
          icon: await zim.illustration(),
        ));
        await zim.close();
      } catch (e) {
        infos.add(_ZimCardInfo(f, error: e.toString()));
      }
    }
    if (mounted) setState(() => _zims = infos);
  }

  @override
  Widget build(BuildContext context) {
    final zims = _zims;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: zims == null
          ? const Center(child: CircularProgressIndicator())
          : zims.isEmpty
              ? _EmptyLibrary(dir: PrepperLibrary.instance.zimDir.path)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: zims.length,
                  itemBuilder: (context, i) => _ZimCard(
                    info: zims[i],
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ZimReaderPage(path: zims[i].file.path),
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _ZimCard extends StatelessWidget {
  const _ZimCard({required this.info, required this.onOpen});
  final _ZimCardInfo info;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final size = humanSize(info.file.lengthSync());
    final name = info.file.uri.pathSegments.last;
    final broken = info.error != null;
    return Card(
      child: ListTile(
        leading: broken
            ? const Icon(Icons.error_outline, color: Colors.redAccent)
            : info.icon != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(info.icon!, width: 42, height: 42),
                  )
                : const Icon(Icons.menu_book, size: 36),
        title: Text(info.title ?? name),
        subtitle: Text(
          broken
              ? 'Archivo dañado o incompleto — $name'
              : '${info.description ?? ''}\n$name · $size',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: !broken,
        enabled: !broken,
        onTap: broken ? null : onOpen,
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.dir});
  final String dir;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 72),
            const SizedBox(height: 16),
            Text('Tu biblioteca está vacía',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Descarga Wikipedia, guías médicas y más desde el Depósito, '
              'o copia archivos .zim a:\n$dir',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
