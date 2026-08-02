import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/relay_policy.dart';

/// El relevo multi-salto es lo que hace que un SOS llegue MÁS ALLÁ de tus
/// vecinos inmediatos. La supresión anti-inundación contaba cada datagrama
/// recibido, pero dos fuentes de eco inflaban esa cuenta sin que ningún nodo
/// hubiera relevado nada: las tres radios de la app entregando la misma copia,
/// y lan_transport enviando por multicast + broadcast + unicast a la vez.
/// Resultado: un solo emisor disparaba el umbral y el SOS moría en el primer
/// salto, justo en la configuración normal.
void main() {
  group('el eco de mis propias radios no cuenta como repetición', () {
    test('el mismo envío por tres transportes cuenta UNA vez', () {
      final c = RelayHeardCounter();
      // Mismo hopLimit = mismo envío, oído por tres radios distintas.
      c.heard(msgId: 1, hopLimit: 3);
      c.heard(msgId: 1, hopLimit: 3);
      c.heard(msgId: 1, hopLimit: 3);
      expect(c.countFor(1), 1,
          reason: 'tres radios oyendo el MISMO envío no son tres repetidores');
    });

    test('multicast+broadcast+unicast del mismo transporte cuentan una', () {
      final c = RelayHeardCounter();
      for (var i = 0; i < 3; i++) {
        c.heard(msgId: 1, hopLimit: 3);
      }
      expect(c.countFor(1), 1);
    });

    test('un relevo real (menos saltos) SÍ suma', () {
      final c = RelayHeardCounter();
      c.heard(msgId: 1, hopLimit: 3); // el emisor
      c.heard(msgId: 1, hopLimit: 2); // alguien lo relevó
      expect(c.countFor(1), 2);
    });

    test('mensajes distintos no se mezclan', () {
      final c = RelayHeardCounter();
      c.heard(msgId: 1, hopLimit: 3);
      c.heard(msgId: 2, hopLimit: 3);
      expect(c.countFor(1), 1);
      expect(c.countFor(2), 1);
    });

    test('olvidar un mensaje libera su cuenta', () {
      final c = RelayHeardCounter()..heard(msgId: 1, hopLimit: 3);
      c.forget(1);
      expect(c.countFor(1), 0);
    });
  });

  group('cuándo relevar', () {
    test('un SOS oído solo del emisor SÍ se releva', () {
      // El caso que estaba roto: tu vecino grita, tú eres el único que lo
      // oye, y tu relevo es la ÚNICA forma de que llegue a la otra manzana.
      expect(shouldRelay(heard: 1, type: RelayType.sos), isTrue);
    });

    test('con tres repeticiones distintas, callar ahorra aire', () {
      expect(shouldRelay(heard: 3, type: RelayType.sos), isFalse);
    });

    test('el chat se suprime antes que el SOS', () {
      expect(shouldRelay(heard: 2, type: RelayType.normal), isFalse);
      expect(shouldRelay(heard: 2, type: RelayType.sos), isTrue);
    });
  });
}
