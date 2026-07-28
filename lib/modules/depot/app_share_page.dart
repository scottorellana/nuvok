// "Pasar Nuvok a otro teléfono" — sin internet.
//
// En un apagón tu vecino no puede descargarla: no hay red. Pero tú ya la
// tienes. Esta pantalla levanta un servidor local y muestra un QR para que
// se conecte a tu WiFi/hotspot y la instale.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/locale_service.dart';
import 'app_share.dart';

class AppSharePage extends StatefulWidget {
  const AppSharePage({super.key});

  @override
  State<AppSharePage> createState() => _AppSharePageState();
}

class _AppSharePageState extends State<AppSharePage> {
  final _server = AppShareServer.instance;
  bool _busy = false;
  String? _error;

  Future<void> _toggle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_server.running) {
      await _server.stop();
    } else {
      final url = await _server.start();
      if (url == null && mounted) {
        _error = tr(context, 'shareAppFailed');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final capability = AppShare.capability;
    final url = _server.url;

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'shareAppTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr(context, 'shareAppIntro')),
            ),
          ),
          const SizedBox(height: 12),

          if (capability == ShareCapability.cannotShareApple)
            // Honestidad: Apple no permite instalar apps desde otra app.
            // Mejor decirlo que ofrecer un botón que no puede funcionar.
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tr(context, 'shareAppIosTitle'),
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(tr(context, 'shareAppIosBody')),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                            data: 'https://nuvok.org', size: 180),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                        child: SelectableText('https://nuvok.org')),
                  ],
                ),
              ),
            )
          else ...[
            FilledButton.icon(
              onPressed: _busy ? null : _toggle,
              icon: Icon(_server.running ? Icons.stop : Icons.wifi_tethering),
              label: Text(_server.running
                  ? tr(context, 'shareAppStop')
                  : tr(context, 'shareAppStart')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (url != null) ...[
              const SizedBox(height: 20),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(14),
                  child: QrImageView(data: url, size: 220),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: SelectableText(url,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 16)),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr(context, 'codeCopied'))));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(tr(context, 'copyCode')),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(tr(context, 'shareAppSteps')),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
