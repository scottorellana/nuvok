// Banner de estado del mesh + hoja del Asistente de conexión.
// Siempre visible en Comunicación: verde cuando hay pares (y por qué
// transporte), ámbar cuando busca — tocar abre pasos grandes, uno por
// tarjeta, pensados para leerse en pánico.
import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import 'connection_advisor.dart';
import 'transport_health.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.healths,
    required this.searching,
  });

  final List<TransportHealth> healths;
  final Duration searching;

  int get _peerTotal => healths.fold(0, (a, h) => a + h.peers);

  static const _transportLabels = {
    'ble': 'Bluetooth',
    'lan': 'WiFi',
    'wifi-direct': 'WiFi Direct',
    'lora': 'LoRa',
  };

  String _viaLabel() {
    final active = [
      for (final h in healths)
        if (h.peers > 0) _transportLabels[h.name] ?? h.name,
    ];
    return active.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final connected = _peerTotal > 0;
    final color = connected ? Colors.green : Colors.orange;
    final title = connected
        ? '${tr(context, 'meshBannerConnected').replaceFirst('{n}', '$_peerTotal')} · ${_viaLabel()}'
        : tr(context, 'meshBannerSearching');
    return Material(
      color: color.withValues(alpha: 0.15),
      child: InkWell(
        onTap: connected ? null : () => _openAssistant(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(connected ? Icons.check_circle : Icons.wifi_find,
                  color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (!connected)
                      Text(tr(context, 'meshBannerTapHelp'),
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (!connected) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _openAssistant(BuildContext context) {
    final steps = ConnectionAdvisor.advise(
      healths: healths,
      platform: Theme.of(context).platform,
      searching: searching,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AssistantSheet(steps: steps),
    );
  }
}

class _AssistantSheet extends StatelessWidget {
  const _AssistantSheet({required this.steps});
  final List<AdvisorStep> steps;

  (String, String) _texts(BuildContext c, AdvisorStepKind kind) =>
      switch (kind) {
        AdvisorStepKind.bluetoothOff =>
          (tr(c, 'advisorBtOff'), tr(c, 'advisorBtOffBody')),
        AdvisorStepKind.bluetoothPermission =>
          (tr(c, 'advisorBtPerm'), tr(c, 'advisorBtPermBody')),
        AdvisorStepKind.hotspot =>
          (tr(c, 'advisorHotspot'), tr(c, 'advisorHotspotBody')),
        AdvisorStepKind.lora =>
          (tr(c, 'advisorLora'), tr(c, 'advisorLoraBody')),
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, 'advisorTitle'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (steps.isEmpty) Text(tr(context, 'meshBannerSearching')),
              for (final (i, step) in steps.indexed) ...[
                Builder(builder: (c) {
                  final (title, body) = _texts(c, step.kind);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}. $title',
                              style: Theme.of(c)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(body, style: Theme.of(c).textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
