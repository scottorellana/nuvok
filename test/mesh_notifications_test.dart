import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_envelope.dart';
import 'package:nuvok/modules/mesh/mesh_notifications.dart';

// Qué mensajes del mesh merecen una notificación del sistema. En una
// emergencia un SOS entrante DEBE avisar aunque la app esté en segundo plano;
// pero no debemos molestar con beacons, ACKs, ni con lo que uno mismo manda,
// ni duplicar lo que ya se ve en pantalla.
void main() {
  bool decide({
    required bool foreground,
    required MeshType type,
    required bool fromSelf,
  }) =>
      MeshNotifications.shouldNotify(
          foreground: foreground, type: type, fromSelf: fromSelf);

  test('SOS entrante en segundo plano SÍ notifica', () {
    expect(decide(foreground: false, type: MeshType.sos, fromSelf: false),
        isTrue);
  });

  test('chat entrante en segundo plano SÍ notifica', () {
    expect(decide(foreground: false, type: MeshType.chat, fromSelf: false),
        isTrue);
  });

  test('nada propio notifica (no me aviso de mis propios mensajes)', () {
    expect(decide(foreground: false, type: MeshType.sos, fromSelf: true),
        isFalse);
    expect(decide(foreground: false, type: MeshType.chat, fromSelf: true),
        isFalse);
  });

  test('en primer plano NO notifica — la UI/alarma ya lo muestra', () {
    expect(
        decide(foreground: true, type: MeshType.sos, fromSelf: false), isFalse);
    expect(decide(foreground: true, type: MeshType.chat, fromSelf: false),
        isFalse);
  });

  test('ruido de protocolo nunca notifica', () {
    for (final t in [
      MeshType.beacon,
      MeshType.ack,
      MeshType.position,
      MeshType.sosCancel,
    ]) {
      expect(decide(foreground: false, type: t, fromSelf: false), isFalse,
          reason: '$t no debe molestar al usuario');
    }
  });
}
