// Supresión de inundación del relevo multi-salto.
//
// El relevo es lo que hace que un SOS llegue MÁS ALLÁ de tus vecinos
// inmediatos. La supresión (estilo Meshtastic) cuenta cuántas veces se repitió
// ya un mensaje: si la red lo hizo suficiente, tu relevo solo gasta aire.
//
// EL FALLO: se contaba CADA DATAGRAMA recibido. Dos fuentes de eco inflaban la
// cuenta sin que ningún nodo hubiera relevado nada:
//   1. Las tres radios de la app (BLE + WiFi multicast + WiFi Direct) entregan
//      la MISMA copia del mismo emisor.
//   2. lan_transport envía por multicast, broadcast Y unicast a la vez.
// Con la configuración normal, un solo emisor disparaba el umbral y el nodo
// cancelaba su relevo: el SOS moría en el primer salto.
//
// LA SEÑAL CORRECTA: un relevo real llega con hopLimit MENOR (cada salto lo
// decrementa), mientras que TODOS los ecos de un mismo envío — venga por la
// radio que venga — llegan con el mismo hopLimit. Se cuenta una vez por
// número de saltos restantes.
//
// No es perfecto — dos relevos del mismo nivel por la misma radio cuentan
// como uno — pero falla del lado seguro: una retransmisión de más es aire
// gastado; una de menos es un grito de auxilio que no llega.

enum RelayType { sos, normal }

/// Cuántas repeticiones distintas hacen falta para callarse.
///
/// El SOS aguanta más antes de suprimirse: un chat duplicado es ruido, un SOS
/// duplicado puede ser una vida.
int suppressThreshold(RelayType type) => type == RelayType.sos ? 3 : 2;

bool shouldRelay({required int heard, required RelayType type}) =>
    heard < suppressThreshold(type);

/// Cuenta repeticiones distintas de cada mensaje.
class RelayHeardCounter {
  final Map<int, Set<int>> _copiesByMsg = {};

  /// [hopLimit] son los saltos que le quedaban al mensaje: identifica una
  /// repetición real (menos saltos) frente al eco de un mismo envío, que
  /// llega con el mismo número por todas las radios.
  void heard({required int msgId, required int hopLimit}) {
    (_copiesByMsg[msgId] ??= <int>{}).add(hopLimit);
  }

  int countFor(int msgId) => _copiesByMsg[msgId]?.length ?? 0;

  void forget(int msgId) => _copiesByMsg.remove(msgId);
}
