// Tarjeta "Punto de encuentro" en Comunicación: quién llegó / quién falta
// (posiciones vivas del mesh) y un botón para rutear hasta el punto.
// El punto se marca en el mapa (kind meetingPoint) y viaja por el mesh a
// todo el grupo — recomendación #1 de protección civil hecha software.
import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import '../../core/shell_nav.dart';
import '../maps/map_focus.dart';
import '../maps/map_overlays.dart';
import '../maps/meeting_point.dart';
import 'position_store.dart';

class MeetingPointCard extends StatelessWidget {
  const MeetingPointCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [OverlayStore.instance, PositionStore.instance.peers]),
      builder: (context, _) {
        final point = activeMeetingPoint(OverlayStore.instance.overlays);
        if (point == null) return const SizedBox.shrink();
        final positions = PositionStore.instance.recent();
        final st = meetingStatus(point, positions);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tr(context, 'mpTitle')}: ${point.name ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        MapFocus.go(point.anchor);
                        ShellNav.goMaps();
                      },
                      child: Text(tr(context, 'mpGo')),
                    ),
                  ],
                ),
                if (positions.isEmpty)
                  Text(tr(context, 'mpNoPositions'),
                      style: Theme.of(context).textTheme.bodySmall)
                else ...[
                  Text(
                    '✅ ${tr(context, 'mpArrived')} (${st.arrived.length}): '
                    '${st.arrived.map((p) => p.name).join(', ')}',
                  ),
                  Text(
                    '🕐 ${tr(context, 'mpPending')} (${st.pending.length}): '
                    '${st.pending.map((p) => p.name).join(', ')}',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
