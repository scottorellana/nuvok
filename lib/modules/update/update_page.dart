// Update UI: a global banner that appears when a newer version is available
// (checked opportunistically, never blocking offline use), plus a full page
// with details, download progress, and the platform-appropriate install
// action. Lives in Depósito → App, next to the other "get more" tabs.
import 'package:flutter/material.dart';

import 'update_service.dart';

/// Thin banner shown app-wide, same visual language as the low-battery
/// banner — an update is good news, so it's olive instead of red.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UpdateService.instance,
      builder: (context, _) {
        final u = UpdateService.instance;
        if (!u.updateAvailable) return const SizedBox.shrink();
        final v = u.latest?.version ?? '';
        return Material(
          color: const Color(0xFF4A5A2E),
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.system_update, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      u.state == UpdateState.downloaded
                          ? 'Actualización $v lista para instalar.'
                          : 'Hay una actualización disponible: $v',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: onOpen,
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.white),
                    child: Text(u.state == UpdateState.downloaded
                        ? 'INSTALAR'
                        : 'VER'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final _service = UpdateService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChange);
    if (_service.state == UpdateState.idle) _service.check();
  }

  @override
  void dispose() {
    _service.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final u = _service;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actualizaciones', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Prepper Pad revisa si hay una versión nueva cuando tienes '
            'internet; funciona igual sin conexión. Nunca se actualiza '
            'solo — tú decides cuándo instalar.',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apps, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Versión instalada: ${u.currentVersion ?? '…'}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (u.state == UpdateState.checking)
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        OutlinedButton.icon(
                          onPressed: () => u.check(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Buscar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatus(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    final u = _service;
    switch (u.state) {
      case UpdateState.idle:
      case UpdateState.checking:
        return const Text('Buscando…', style: TextStyle(color: Colors.grey));
      case UpdateState.upToDate:
        return const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text('Ya tienes la última versión.'),
          ],
        );
      case UpdateState.error:
        return Text(
          'No se pudo comprobar (sin internet o el servidor no responde). '
          'Se sigue usando la versión instalada normalmente.',
          style: TextStyle(color: Theme.of(context).hintColor),
        );
      case UpdateState.available:
        final asset = u.latest == null
            ? null
            : u.latest!.platforms[_platformKey()];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nueva versión: ${u.latest?.version}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.lightGreen)),
            if (u.latest?.notes.isNotEmpty ?? false) ...[
              const SizedBox(height: 6),
              Text(u.latest!.notes),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: asset == null ? null : u.download,
              icon: const Icon(Icons.download),
              label: Text(asset == null
                  ? 'No disponible para este dispositivo'
                  : 'Descargar actualización'
                      '${asset.sizeBytes != null ? ' (${_humanSize(asset.sizeBytes!)})' : ''}'),
            ),
          ],
        );
      case UpdateState.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Descargando ${u.latest?.version}…'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: u.downloadProgress),
            const SizedBox(height: 4),
            Text('${(u.downloadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Theme.of(context).hintColor)),
          ],
        );
      case UpdateState.downloaded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.lightGreen, size: 20),
                SizedBox(width: 8),
                Text('Descarga lista.'),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: u.install,
              icon: const Icon(Icons.system_update_alt),
              label: const Text('Instalar ahora'),
            ),
            const SizedBox(height: 6),
            Text(
              'Se abrirá el instalador del sistema — confírmalo ahí.',
              style: TextStyle(
                  color: Theme.of(context).hintColor, fontSize: 12),
            ),
          ],
        );
    }
  }

  String _platformKey() {
    // Mirrors UpdateService._assetForThisPlatform's keys, for the size hint.
    final p = Theme.of(context).platform;
    return p == TargetPlatform.android
        ? 'android'
        : p == TargetPlatform.macOS
            ? 'macos'
            : p == TargetPlatform.windows
                ? 'windows'
                : 'linux';
  }

  String _humanSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var u = 0;
    while (size >= 1024 && u < units.length - 1) {
      size /= 1024;
      u++;
    }
    return '${size.toStringAsFixed(size < 10 && u > 0 ? 1 : 0)} ${units[u]}';
  }
}
