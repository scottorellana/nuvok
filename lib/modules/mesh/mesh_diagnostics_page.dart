// Pantalla de diagnóstico del mesh: qué vías están activas, cuánto tráfico
// real pasó por cada una y qué ocurrió recientemente — todo copiable.
//
// En una app que funciona sin internet no se le pueden pedir registros al
// usuario ni mirar un servidor. Esta pantalla ES la herramienta de soporte.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_service.dart';
import 'mesh_diagnostics.dart';
import 'mesh_service.dart';
import 'transport_health.dart';

class MeshDiagnosticsPage extends StatefulWidget {
  const MeshDiagnosticsPage({super.key});

  @override
  State<MeshDiagnosticsPage> createState() => _MeshDiagnosticsPageState();
}

class _MeshDiagnosticsPageState extends State<MeshDiagnosticsPage> {
  final _diag = MeshDiagnostics.instance;
  final _service = MeshService.instance;

  @override
  void initState() {
    super.initState();
    _diag.addListener(_onChange);
  }

  @override
  void dispose() {
    _diag.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  String _stateLabel(TransportState s) => switch (s) {
        TransportState.connected => 'conectado',
        TransportState.searching => 'buscando',
        TransportState.off => 'apagado',
        TransportState.noPermission => 'sin permiso',
        TransportState.unavailable => 'no disponible',
      };

  List<String> _transportLines() => [
        for (final h in _service.transportHealths.value)
          '${h.name}: ${_stateLabel(h.state)}'
          '${h.peers > 0 ? ' (${h.peers} vecino${h.peers == 1 ? '' : 's'})' : ''}'
          '${h.hint != null ? ' — ${h.hint}' : ''}',
      ];

  void _copy() {
    final text = _diag.snapshotText(
      peers: _service.peerCount.value,
      queued: _service.queuedCount.value,
      transports: _transportLines(),
    );
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(context, 'diagCopied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counters = _diag.counters;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'diagTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: tr(context, 'diagCopy'),
            onPressed: _copy,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(tr(context, 'diagIntro'),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),

          // --- Vías ---
          _section(context, tr(context, 'diagTransports')),
          Card(
            child: Column(
              children: [
                for (final h in _service.transportHealths.value)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      h.state == TransportState.connected
                          ? Icons.check_circle
                          : h.isBlocked
                              ? Icons.error_outline
                              : Icons.search,
                      color: h.state == TransportState.connected
                          ? Colors.green
                          : h.isBlocked
                              ? Colors.orange
                              : null,
                    ),
                    title: Text(h.name),
                    subtitle: Text(_stateLabel(h.state) +
                        (h.hint != null ? ' — ${h.hint}' : '')),
                    trailing: Text('${h.peers}'),
                  ),
                if (_service.transportHealths.value.isEmpty)
                  ListTile(
                    dense: true,
                    title: Text(tr(context, 'diagNoTransports')),
                  ),
              ],
            ),
          ),

          // --- Tráfico real por vía: la prueba de que una radio SÍ entrega ---
          _section(context, tr(context, 'diagTraffic')),
          Card(
            child: Column(
              children: [
                if (counters.isEmpty)
                  ListTile(
                    dense: true,
                    title: Text(tr(context, 'diagNoTraffic')),
                  ),
                for (final e in counters.entries)
                  ListTile(
                    dense: true,
                    title: Text(e.key),
                    subtitle: Text(
                      '↑ ${e.value.sent} (${e.value.sentBytes} B)   '
                      '↓ ${e.value.received} (${e.value.receivedBytes} B)',
                    ),
                    trailing: Icon(
                      e.value.received > 0
                          ? Icons.swap_vert
                          : Icons.arrow_upward,
                      color: e.value.received > 0 ? Colors.green : Colors.grey,
                    ),
                  ),
              ],
            ),
          ),

          // --- Bitácora ---
          _section(context, tr(context, 'diagEvents')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _diag.events.isEmpty
                  ? Text(tr(context, 'diagNoEvents'))
                  : SelectableText(
                      _diag.events.reversed
                          .take(60)
                          .map((e) => '${e.hhmmss}  ${e.message}')
                          .join('\n'),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(_diag.reset),
            icon: const Icon(Icons.delete_outline),
            label: Text(tr(context, 'diagClear')),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}
