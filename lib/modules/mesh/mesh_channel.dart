// A mesh channel is the unit of group security: a human name plus a shared
// AES-256 key. Whoever holds the key reads the channel — same model as LoRa
// mesh radios, so the future radio adapter maps 1:1. The fixed EMERGENCY
// channel is unencrypted and every installation always listens to it: an SOS
// must reach strangers nearby, authenticated or not.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

class MeshChannel {
  MeshChannel({required this.name, required this.key})
      : assert(key.length == 32);

  final String name;
  final Uint8List key;

  /// Stable short id: first 4 bytes of sha256(name + key), hex (8 chars).
  /// Travels in every envelope so receivers know which key to try.
  late final String id = () {
    final digest = crypto.sha256.convert([...utf8.encode(name), ...key]);
    return digest.bytes
        .take(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }();

  bool get isEmergency => identical(this, emergency) || id == emergency.id;

  /// Shareable code (QR / copy-paste): PPMESH1:base64url(name\nkeyhex)
  String toCode() {
    final keyHex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'PPMESH1:${base64Url.encode(utf8.encode('$name\n$keyHex'))}';
  }

  static MeshChannel? fromCode(String code) {
    try {
      if (!code.startsWith('PPMESH1:')) return null;
      final raw = utf8.decode(base64Url.decode(code.substring(8).trim()));
      final nl = raw.indexOf('\n');
      if (nl <= 0) return null;
      final name = raw.substring(0, nl);
      final keyHex = raw.substring(nl + 1);
      if (keyHex.length != 64) return null;
      final key = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        key[i] = int.parse(keyHex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return MeshChannel(name: name, key: key);
    } catch (_) {
      return null;
    }
  }

  static MeshChannel create(String name) {
    final rnd = Random.secure();
    final key = Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256)));
    return MeshChannel(name: name, key: key);
  }

  /// Built-in unencrypted channel every device listens to. Key is all-zero
  /// on purpose: it's an identifier, not a secret — payloads go plaintext.
  static final MeshChannel emergency =
      MeshChannel(name: 'EMERGENCIA', key: Uint8List(32));

  Map<String, dynamic> toJson() => {'name': name, 'key': base64.encode(key)};

  static MeshChannel? fromJson(Map<String, dynamic> j) {
    try {
      final key = Uint8List.fromList(base64.decode(j['key'] as String));
      if (key.length != 32) return null;
      return MeshChannel(name: j['name'] as String, key: key);
    } catch (_) {
      return null;
    }
  }
}
