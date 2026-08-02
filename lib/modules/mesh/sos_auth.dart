// Quién puede apagar un SOS.
//
// El canal de emergencia es deliberadamente abierto: va en claro y con una
// clave de ceros para que CUALQUIER Nuvok al alcance oiga un grito de auxilio
// aunque no comparta canal con la víctima. Esa apertura es correcta para
// OÍR — y era un agujero para CALLAR.
//
// El senderId viaja en claro en la cabecera de cada SOS. Cualquiera que lo
// oiga puede reemitir un sobre `sosCancel` con ese mismo senderId: en cada
// receptor, el SOS de esa persona desaparece del mapa, la alarma se calla y
// el mensaje guardado para store-and-forward se descarta. La víctima no tiene
// forma de notarlo: su teléfono sigue emitiendo cada 60 s creyendo que grita.
//
// La solución no necesita un par de claves ni cambiar el modelo de identidad:
// quien inicia un SOS se guarda un secreto y publica solo su HUELLA. Para
// cancelar, revela el secreto. Verificar es comparar una huella; falsificar
// exige invertir SHA-256. Un tercero que ha oído mil SOS sigue sin poder
// apagar ninguno.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Clave del payload donde viaja la huella del secreto, en el SOS.
const sosCommitmentKey = 'cx';

/// Clave del payload donde viaja el secreto revelado, en la cancelación.
const sosSecretKey = 'cs';

/// 16 bytes: de sobra contra fuerza bruta y barato en un sobre que viaja por
/// BLE, donde cada byte se paga en fragmentos.
const int sosSecretBytes = 16;

/// Secreto nuevo para un SOS. Random.secure() o nada: un secreto predecible
/// es exactamente el agujero que esto cierra.
String newSosSecret() {
  final rnd = Random.secure();
  final bytes =
      Uint8List.fromList(List.generate(sosSecretBytes, (_) => rnd.nextInt(256)));
  return base64Url.encode(bytes);
}

/// Huella pública del secreto. Es lo único que viaja en el SOS.
String sosCommitmentFor(String secret) =>
    sha256.convert(utf8.encode(secret)).toString().substring(0, 32);

/// ¿Este `sosCancel` lo emitió de verdad quien lanzó el SOS?
///
/// [commitment] es la huella que venía en el SOS de esa persona; [secret] el
/// que llega ahora en la cancelación.
///
/// Sin huella conocida se RECHAZA: si este equipo nunca oyó el SOS original,
/// no tiene con qué comprobar nada, y ante la duda es preferible una alarma
/// que sigue sonando de más a una persona a la que dejamos de buscar. Es la
/// misma razón por la que un SOS se releva aunque no entendamos su canal.
bool sosCancelIsAuthentic({String? commitment, String? secret}) {
  if (commitment == null || commitment.isEmpty) return false;
  if (secret == null || secret.isEmpty) return false;
  return sosCommitmentFor(secret) == commitment;
}

/// Huellas de los SOS que este equipo ha oído, por senderId.
///
/// Vive aquí y no en la alarma porque también la necesita el store-and-forward:
/// el nodo que LLEVA el SOS de alguien fuera de rango tiene que poder decidir
/// si lo suelta, y esa decisión es irreversible para esa persona.
class SosCommitments {
  final Map<String, String> _bySender = {};

  /// Registra la huella del SOS de [senderId].
  ///
  /// Las repeticiones del mismo emisor traen la misma huella mientras dure el
  /// SOS; si empieza uno nuevo (tras cancelar), la huella se renueva y esta
  /// sobrescritura es la correcta.
  void remember(String senderId, String? commitment) {
    if (commitment == null || commitment.isEmpty) return;
    _bySender[senderId] = commitment;
  }

  String? commitmentFor(String senderId) => _bySender[senderId];

  /// ¿Se acepta esta cancelación de [senderId]?
  bool accepts(String senderId, String? secret) =>
      sosCancelIsAuthentic(commitment: _bySender[senderId], secret: secret);

  void forget(String senderId) => _bySender.remove(senderId);

  void clear() => _bySender.clear();

  int get length => _bySender.length;
}

/// Lee un campo del payload EN CLARO del canal de emergencia.
///
/// El store-and-forward decide si suelta un SOS antes de saber de qué canal
/// es (lleva mensajes de canales que no son suyos, y eso es deliberado: un
/// nodo tiene que poder transportar el grito de alguien con quien no comparte
/// clave). Para el canal de emergencia, que va en claro por diseño, el campo
/// se puede leer sin descifrar nada.
///
/// Si el payload viene cifrado —cualquier otro canal— esto devuelve null y la
/// cancelación no se acepta. Correcto: ahí el AAD ya liga la cabecera al
/// contenido y un tercero no puede fabricar el sobre.
String? emergencyStringField(List<int> payload, String key) {
  try {
    final decoded = jsonDecode(utf8.decode(payload));
    if (decoded is! Map) return null;
    final v = decoded[key];
    return v is String && v.isNotEmpty ? v : null;
  } catch (_) {
    return null;
  }
}
