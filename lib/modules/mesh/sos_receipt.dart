// Acuse de recibo del SOS: ¿alguien me oyó?
//
// Quien lanza un SOS no tenía forma de saberlo. Esa diferencia decide si te
// quedas donde estás (viene ayuda en camino) o gastas tus últimas fuerzas
// caminando a buscarla. El chat ya mostraba ✓✓ de entrega; el SOS — el
// mensaje del que depende una vida — no confirmaba nada.
//
// Estructura mínima y pura: la UI pregunta cuántos vecinos confirmaron.

/// Saltos que puede dar la confirmación de un SOS.
///
/// Los ACK de chat usan 1 porque el chat es entre vecinos directos. Un SOS se
/// relevó por la malla: su confirmación tiene que poder volver por el mismo
/// camino o quien pidió auxilio nunca se entera. Se acota a 3 para no inundar
/// la malla con confirmaciones.
const int sosAckHopLimit = 3;

class SosReceipts {
  /// msgId del SOS → ids de los vecinos que confirmaron haberlo recibido.
  final Map<String, Set<String>> _heardBy = {};

  /// Registra un SOS propio recién emitido, aún sin confirmaciones.
  void registerSent(String msgId) => _heardBy.putIfAbsent(msgId, () => {});

  /// Procesa un ACK entrante. Se ignoran los de mensajes que no son míos.
  ///
  /// Se cuenta por VECINO, no por ACK recibido: con relevo multi-salto el
  /// mismo acuse puede llegar por dos caminos, y decirle a alguien que "3
  /// personas te oyeron" cuando fue una sola es mentirle sobre su
  /// probabilidad real de rescate.
  void onAck({required String ackedMsgId, required String fromPeer}) {
    final peers = _heardBy[ackedMsgId];
    if (peers == null) return;
    peers.add(fromPeer);
  }

  int confirmationsFor(String msgId) => _heardBy[msgId]?.length ?? 0;

  bool anyoneHeard(String msgId) => confirmationsFor(msgId) > 0;

  /// El SOS terminó (cancelado o resuelto).
  void clear(String msgId) => _heardBy.remove(msgId);
}
