// Motor de reglas del Asistente de conexión. Puro (sin Flutter UI, sin
// side-effects): recibe la salud de los transportes y devuelve los pasos que
// el usuario debe seguir, ordenados por impacto. La UI solo los pinta.
import 'package:flutter/foundation.dart';

import 'transport_health.dart';

enum AdvisorStepKind {
  /// Bluetooth apagado: encenderlo reactiva el transporte de 0 config.
  bluetoothOff,

  /// Permiso Bluetooth denegado a la app.
  bluetoothPermission,

  /// Nadie a la vista y sin red común: crear un hotspot y unir a los demás.
  hotspot,

  /// Información: alcance de kilómetros con radio LoRa.
  lora,
}

@immutable
class AdvisorStep {
  const AdvisorStep(this.kind);
  final AdvisorStepKind kind;
}

class ConnectionAdvisor {
  /// Cuánto esperar antes de sugerir el hotspot cuando todo parece bien
  /// (los bursts de discovery del mesh tardan unos segundos en converger).
  static const Duration hotspotAfter = Duration(seconds: 30);

  static List<AdvisorStep> advise({
    required List<TransportHealth> healths,
    required TargetPlatform platform,
    required Duration searching,
  }) {
    final anyPeers = healths.any((h) => h.peers > 0);
    if (anyPeers) return const [];

    final steps = <AdvisorStep>[];
    TransportHealth? byName(String n) {
      for (final h in healths) {
        if (h.name == n) return h;
      }
      return null;
    }

    final ble = byName('ble');
    if (ble?.state == TransportState.off) {
      steps.add(const AdvisorStep(AdvisorStepKind.bluetoothOff));
    } else if (ble?.state == TransportState.noPermission) {
      steps.add(const AdvisorStep(AdvisorStepKind.bluetoothPermission));
    }

    final lan = byName('lan');
    final noNetwork =
        lan?.hint == 'no_network' || lan?.state == TransportState.off;
    if (noNetwork || searching >= hotspotAfter) {
      steps.add(const AdvisorStep(AdvisorStepKind.hotspot));
    }

    if (searching >= hotspotAfter) {
      steps.add(const AdvisorStep(AdvisorStepKind.lora));
    }
    return steps;
  }
}
