import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_envelope.dart';
import 'package:nuvok/modules/mesh/sos_receipt.dart';

/// Quien lanza un SOS no sabía si alguien lo había recibido. Esa diferencia
/// decide si te quedas donde estás (viene ayuda) o gastas tus últimas fuerzas
/// caminando a buscarla. El chat sí confirmaba entrega (✓✓) y el SOS no.
void main() {
  group('acuse de recibo del SOS', () {
    test('un ACK del tipo correcto se cuenta', () {
      final r = SosReceipts();
      r.registerSent('msg-1');
      expect(r.confirmationsFor('msg-1'), 0);
      r.onAck(ackedMsgId: 'msg-1', fromPeer: 'vecino-a');
      expect(r.confirmationsFor('msg-1'), 1);
      expect(r.anyoneHeard('msg-1'), isTrue);
    });

    test('dos vecinos distintos cuentan dos veces', () {
      final r = SosReceipts()..registerSent('m');
      r.onAck(ackedMsgId: 'm', fromPeer: 'a');
      r.onAck(ackedMsgId: 'm', fromPeer: 'b');
      expect(r.confirmationsFor('m'), 2);
    });

    test('el mismo vecino repitiendo ACK no infla la cuenta', () {
      // Con relevo multi-salto el mismo ACK puede llegar por dos caminos:
      // decirle a alguien "3 personas te oyeron" cuando fue una sola es
      // mentirle sobre su probabilidad de rescate.
      final r = SosReceipts()..registerSent('m');
      r.onAck(ackedMsgId: 'm', fromPeer: 'a');
      r.onAck(ackedMsgId: 'm', fromPeer: 'a');
      expect(r.confirmationsFor('m'), 1);
    });

    test('un ACK de un SOS que no es mío se ignora', () {
      final r = SosReceipts()..registerSent('mio');
      r.onAck(ackedMsgId: 'ajeno', fromPeer: 'a');
      expect(r.confirmationsFor('mio'), 0);
      expect(r.anyoneHeard('ajeno'), isFalse);
    });

    test('sin ACK, nadie oyó: la app no debe fingir', () {
      final r = SosReceipts()..registerSent('m');
      expect(r.anyoneHeard('m'), isFalse);
    });

    test('cancelar el SOS limpia su acuse', () {
      final r = SosReceipts()..registerSent('m');
      r.onAck(ackedMsgId: 'm', fromPeer: 'a');
      r.clear('m');
      expect(r.confirmationsFor('m'), 0);
    });
  });

  group('el ACK debe poder cruzar el relevo', () {
    test('un ACK de SOS viaja más de un salto', () {
      // El ACK de chat usa hopLimit 1 porque el chat es entre vecinos
      // directos. Un SOS se relevó por la malla: su confirmación tiene que
      // poder volver por el mismo camino, o quien pidió auxilio no se entera.
      expect(sosAckHopLimit, greaterThan(1));
      expect(sosAckHopLimit, lessThanOrEqualTo(4),
          reason: 'tampoco inundar la malla con confirmaciones');
    });

    test('el tipo de sobre del ACK sigue siendo ack', () {
      expect(MeshType.ack.index, 4, reason: 'contrato binario con Swift');
    });
  });
}
