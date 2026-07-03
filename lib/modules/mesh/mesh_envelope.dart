// The Prepper Mesh wire format. One compact binary envelope for every
// transport (WiFi now, BLE and LoRa later): fixed header + UTF-8 sender name
// + payload. Payloads are AES-256-GCM sealed with the channel key, except on
// the EMERGENCY channel which is deliberately plaintext.
//
// Layout (little-endian):
//   magic 'PM01' (4B) | msgId (8B) | channelId (4B, raw bytes of the hex id)
//   | senderId (8B) | type (1B) | hopLimit (1B) | timestampMs (8B)
//   | nameLen (1B) + name utf8 | payloadLen (2B) + payload
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'mesh_channel.dart';

enum MeshType { chat, position, sos, sosCancel, ack, beacon }

class MeshEnvelope {
  MeshEnvelope({
    required this.msgId,
    required this.channelId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.hopLimit,
    required this.timestampMs,
    required this.payload,
  });

  final int msgId;
  final String channelId; // 8 hex chars
  final String senderId; // 16 hex chars
  final String senderName;
  final MeshType type;
  final int hopLimit;
  final int timestampMs;
  final Uint8List payload;

  static const _magic = [0x50, 0x4D, 0x30, 0x31]; // 'PM01'

  static int newMsgId() {
    final rnd = Random.secure();
    // 63-bit random id (keeps it a positive Dart int everywhere).
    return (rnd.nextInt(1 << 31) << 32) | rnd.nextInt(1 << 31) << 1 |
        rnd.nextInt(2);
  }

  MeshEnvelope withHop(int newHopLimit) => MeshEnvelope(
        msgId: msgId,
        channelId: channelId,
        senderId: senderId,
        senderName: senderName,
        type: type,
        hopLimit: newHopLimit,
        timestampMs: timestampMs,
        payload: payload,
      );

  Uint8List encode() {
    final name = utf8.encode(
        senderName.length > 40 ? senderName.substring(0, 40) : senderName);
    final total = 4 + 8 + 4 + 8 + 1 + 1 + 8 + 1 + name.length + 2 +
        payload.length;
    final out = ByteData(total);
    var o = 0;
    for (final b in _magic) {
      out.setUint8(o++, b);
    }
    out.setUint64(o, msgId, Endian.little);
    o += 8;
    for (var i = 0; i < 4; i++) {
      out.setUint8(
          o++, int.parse(channelId.substring(i * 2, i * 2 + 2), radix: 16));
    }
    for (var i = 0; i < 8; i++) {
      out.setUint8(
          o++, int.parse(senderId.substring(i * 2, i * 2 + 2), radix: 16));
    }
    out.setUint8(o++, type.index);
    out.setUint8(o++, hopLimit);
    out.setUint64(o, timestampMs, Endian.little);
    o += 8;
    out.setUint8(o++, name.length);
    for (final b in name) {
      out.setUint8(o++, b);
    }
    out.setUint16(o, payload.length, Endian.little);
    o += 2;
    final bytes = out.buffer.asUint8List();
    bytes.setRange(o, o + payload.length, payload);
    return bytes;
  }

  static MeshEnvelope? decode(Uint8List bytes) {
    try {
      if (bytes.length < 4 + 8 + 4 + 8 + 1 + 1 + 8 + 1 + 2) return null;
      for (var i = 0; i < 4; i++) {
        if (bytes[i] != _magic[i]) return null;
      }
      final bd = ByteData.sublistView(bytes);
      var o = 4;
      final msgId = bd.getUint64(o, Endian.little);
      o += 8;
      final channelId = bytes
          .sublist(o, o + 4)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      o += 4;
      final senderId = bytes
          .sublist(o, o + 8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      o += 8;
      final typeIdx = bd.getUint8(o++);
      if (typeIdx >= MeshType.values.length) return null;
      final hopLimit = bd.getUint8(o++);
      final ts = bd.getUint64(o, Endian.little);
      o += 8;
      final nameLen = bd.getUint8(o++);
      if (o + nameLen + 2 > bytes.length) return null;
      final name = utf8.decode(bytes.sublist(o, o + nameLen),
          allowMalformed: true);
      o += nameLen;
      final payloadLen = bd.getUint16(o, Endian.little);
      o += 2;
      if (o + payloadLen > bytes.length) return null;
      return MeshEnvelope(
        msgId: msgId,
        channelId: channelId,
        senderId: senderId,
        senderName: name,
        type: MeshType.values[typeIdx],
        hopLimit: hopLimit,
        timestampMs: ts,
        payload: bytes.sublist(o, o + payloadLen),
      );
    } catch (_) {
      return null;
    }
  }
}

final _aesGcm = AesGcm.with256bits();

/// Seals a JSON payload for [channel]: AES-256-GCM (nonce ‖ ciphertext ‖ mac).
/// The EMERGENCY channel is plaintext by design.
Future<Uint8List> sealPayload(
    Map<String, dynamic> json, MeshChannel channel) async {
  final clear = utf8.encode(jsonEncode(json));
  if (channel.isEmergency) return Uint8List.fromList(clear);
  final secret = SecretKey(channel.key);
  final box = await _aesGcm.encrypt(clear, secretKey: secret);
  return Uint8List.fromList(
      [...box.nonce, ...box.cipherText, ...box.mac.bytes]);
}

/// Opens a sealed payload; null when the key doesn't match or data is
/// corrupt. Emergency payloads are plain JSON.
Future<Map<String, dynamic>?> openPayload(
    Uint8List data, MeshChannel channel) async {
  try {
    if (channel.isEmergency) {
      return jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    }
    if (data.length < 12 + 16) return null;
    final nonce = data.sublist(0, 12);
    final mac = Mac(data.sublist(data.length - 16));
    final cipher = data.sublist(12, data.length - 16);
    final clear = await _aesGcm.decrypt(
      SecretBox(cipher, nonce: nonce, mac: mac),
      secretKey: SecretKey(channel.key),
    );
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
