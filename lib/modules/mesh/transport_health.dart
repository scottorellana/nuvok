// Salud observable de un transporte del mesh. Los transportes hoy degradan
// en silencio (patrón deliberado: nunca tiran el mesh); esto agrega
// visibilidad — QUÉ transporte está activo, cuántos pares ve y, si no
// funciona, POR QUÉ — para que el Asistente de conexión pueda guiar al
// usuario en vez de dejarlo adivinando.
import 'package:flutter/foundation.dart';

enum TransportState {
  /// Radio apagada por el usuario (ej. Bluetooth off) — accionable.
  off,

  /// El hardware no existe o la plataforma no lo soporta.
  unavailable,

  /// Permiso denegado por el usuario — accionable en ajustes de la app.
  noPermission,

  /// Radio encendida, buscando pares.
  searching,

  /// Al menos un par vivo por este transporte.
  connected,
}

@immutable
class TransportHealth {
  const TransportHealth({
    required this.name,
    required this.state,
    this.peers = 0,
    this.hint,
  });

  /// Nombre del transporte: 'ble', 'lan', 'wifi_direct', 'lora'.
  final String name;
  final TransportState state;

  /// Pares vivos vía este transporte (lo rellena MeshService desde el router).
  final int peers;

  /// Pista corta del problema: 'bluetooth_off', 'no_adapter', 'no_network'…
  final String? hint;

  /// True si el estado requiere una acción del usuario para funcionar.
  bool get isBlocked =>
      state == TransportState.off || state == TransportState.noPermission;

  TransportHealth copyWith({TransportState? state, int? peers, String? hint}) =>
      TransportHealth(
        name: name,
        state: state ?? this.state,
        peers: peers ?? this.peers,
        hint: hint ?? this.hint,
      );
}

/// Transportes que reportan salud. Interfaz separada (no en MeshTransport)
/// para no romper fakes de tests ni transportes que aún no reportan.
abstract class HealthReporting {
  ValueNotifier<TransportHealth> get health;
}
