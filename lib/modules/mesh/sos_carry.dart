// "Guardar y reenviar" para el SOS de OTRAS personas.
//
// El problema real: hoy un SOS solo llega a quien esté en rango en ese
// instante. Si el rescatista pasa por la zona diez minutos después, nunca se
// entera. Cada teléfono con Nuvok puede ser un mensajero: guarda el SOS que
// oyó y se lo entrega a quien aparezca luego.
//
// Decisiones deliberadas:
// - SOLO se lleva el SOS (y su cancelación). El chat de otros es privado y
//   no justifica ocupar memoria ni aire ajeno; el SOS es público por diseño
//   y es cuestión de vida.
// - Caduca: un SOS de hace horas confunde más de lo que ayuda.
// - Acotado: un teléfono en emergencia no puede quedarse sin memoria.
// - Una cancelación del mismo remitente descarta su SOS: si ya está a salvo,
//   seguir propagando su grito es dañino.
import 'dart:typed_data';

import 'mesh_envelope.dart';

class CarriedMessage {
  CarriedMessage({
    required this.msgId,
    required this.senderId,
    required this.type,
    required this.bytes,
    required this.heardAt,
  });

  final int msgId;
  final String senderId;
  final MeshType type;
  final Uint8List bytes;
  final DateTime heardAt;
}

class SosCarry {
  SosCarry({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Cuánto tiempo tiene sentido seguir repartiendo un SOS ajeno.
  static const Duration ttl = Duration(minutes: 30);

  /// Tope de mensajes en tránsito (memoria acotada en gama baja).
  static const int maxCarried = 20;

  final List<CarriedMessage> _carried = [];

  /// Mensajes vigentes (los caducados se descartan al consultarlos).
  List<CarriedMessage> get pending {
    final now = _clock();
    _carried.removeWhere((m) => now.difference(m.heardAt) > ttl);
    return List.unmodifiable(_carried);
  }

  /// Ofrece un sobre ajeno recién oído. Decide solo si vale la pena llevarlo.
  void offer(MeshEnvelope env) {
    // Una cancelación no se lleva: se usa para DEJAR de llevar.
    if (env.type == MeshType.sosCancel) {
      _carried.removeWhere(
          (m) => m.type == MeshType.sos && m.senderId == env.senderId);
      return;
    }
    if (env.type != MeshType.sos) return;
    if (_carried.any((m) => m.msgId == env.msgId)) return;

    _carried.add(CarriedMessage(
      msgId: env.msgId,
      senderId: env.senderId,
      type: env.type,
      bytes: env.encode(),
      heardAt: _clock(),
    ));
    // Si desborda, se sueltan los más viejos: el SOS reciente es el que más
    // probablemente sigue sin atender.
    while (_carried.length > maxCarried) {
      _carried.removeAt(0);
    }
  }

  /// Datagramas a reenviar cuando aparece un vecino nuevo.
  List<Uint8List> datagramsToForward() =>
      [for (final m in pending) m.bytes];

  void clear() => _carried.clear();
}
