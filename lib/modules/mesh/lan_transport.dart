// WiFi-LAN transport: UDP datagrams to a well-known multicast group with a
// broadcast fallback (some Android vendors filter one but not the other).
// Covers "same house / camp router / tablet hotspot" — no internet needed.
// On Android a MulticastLock is required or the radio silently drops
// multicast; we acquire it via a tiny MethodChannel.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'mesh_transport.dart';

class LanTransport implements MeshTransport {
  LanTransport({this.port = 47777});

  final int port;
  static final InternetAddress _group = InternetAddress('239.255.77.77');
  static const _lock = MethodChannel('prepper/multicast');

  RawDatagramSocket? _socket;
  final _data = StreamController<Uint8List>.broadcast();

  @override
  String get name => 'lan';

  @override
  Stream<Uint8List> get onData => _data.stream;

  @override
  Future<void> start() async {
    if (_socket != null) return;
    try {
      await _lock.invokeMethod('acquire');
    } catch (_) {
      // Not Android (or the channel isn't there) — fine.
    }
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
      reusePort: !Platform.isAndroid && !Platform.isWindows,
    );
    socket.broadcastEnabled = true;
    socket.multicastLoopback = true;
    try {
      socket.joinMulticast(_group);
    } catch (_) {
      // Some networks/interfaces refuse multicast; broadcast still works.
    }
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg != null && dg.data.isNotEmpty) {
        _data.add(Uint8List.fromList(dg.data));
      }
    });
    _socket = socket;
  }

  @override
  Future<void> stop() async {
    try {
      await _lock.invokeMethod('release');
    } catch (_) {}
    _socket?.close();
    _socket = null;
  }

  @override
  Future<void> send(Uint8List datagram) async {
    final s = _socket;
    if (s == null) return;
    try {
      s.send(datagram, _group, port);
    } catch (_) {}
    try {
      s.send(datagram, InternetAddress('255.255.255.255'), port);
    } catch (_) {}
  }
}
