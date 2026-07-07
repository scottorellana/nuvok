// WiFi-LAN transport: UDP datagrams to a well-known multicast group with a
// broadcast fallback (some Android vendors filter one but not the other).
// Covers "same house / camp router / tablet hotspot" — no internet needed.
// On Android a MulticastLock is required or the radio silently drops
// multicast; we acquire it via a tiny MethodChannel.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'lan_discovery.dart';
import 'mesh_transport.dart';

class LanTransport implements MeshTransport {
  LanTransport({this.port = 47777, this.deviceId});

  final int port;

  /// When set, the transport also announces/browses `_prepperpad._udp` via
  /// Bonjour — the only LAN discovery path available on iOS without Apple's
  /// multicast entitlement. Null (tests, LoRa-only builds) skips it.
  final String? deviceId;

  static final InternetAddress _group = InternetAddress('239.255.77.77');
  static const _lock = MethodChannel('prepper/multicast');

  LanDiscovery? _discovery;

  RawDatagramSocket? _socket;
  StreamController<Uint8List> _data = StreamController<Uint8List>.broadcast();

  // Source addresses we've received datagrams from recently. Once we've heard
  // even one packet from a peer, we send future traffic to it by UNICAST too —
  // which keeps working when the WiFi AP or phone hotspot filters multicast /
  // broadcast between clients (the single most common reason mesh chat "sends
  // but never arrives" on real networks).
  final Map<String, (InternetAddress, DateTime)> _peerAddrs = {};
  static const _peerAddrTtl = Duration(minutes: 3);

  @override
  String get name => 'lan';

  @override
  Stream<Uint8List> get onData => _data.stream;

  @override
  Future<void> start() async {
    if (_socket != null) return;
    // A previous stop() closes the stream controller; recreate it so a
    // stop→start cycle (battery saver, app resume) doesn't leave reception
    // permanently dead.
    if (_data.isClosed) {
      _data = StreamController<Uint8List>.broadcast();
    }
    try {
      await _lock.invokeMethod('acquire');
    } catch (_) {
      // Not Android (or the channel isn't there) — fine.
    }
    RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: !Platform.isAndroid && !Platform.isWindows,
      );
    } catch (e) {
      // Port may be in use by another instance or the OS may block
      // multicast. Fail gracefully — the mesh runs on other transports.
      return;
    }
    socket.broadcastEnabled = true;
    socket.multicastLoopback = true;
    // Join the group on EVERY interface, not just the default one. This is
    // what lets two devices find each other on real WiFi AND two app
    // instances find each other over loopback on one machine (the default
    // interface alone skips loopback, so same-host peers wouldn't see each
    // other).
    var joinedAny = false;
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        try {
          socket.joinMulticast(_group, iface);
          joinedAny = true;
        } catch (_) {
          // This interface refused the join; others may still work.
        }
      }
    } catch (_) {
      // Enumerating interfaces failed; fall through to the default join.
    }
    if (!joinedAny) {
      try {
        socket.joinMulticast(_group);
      } catch (_) {
        // No multicast at all; the broadcast fallback still carries traffic.
      }
    }
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg != null && dg.data.isNotEmpty) {
        // Remember who this came from so we can reach them by unicast even if
        // multicast/broadcast later gets filtered.
        _peerAddrs[dg.address.address] = (dg.address, DateTime.now());
        if (!_data.isClosed) _data.add(Uint8List.fromList(dg.data));
      }
    });
    _socket = socket;

    // Bonjour discovery seeds the unicast address book, so peers are
    // reachable even where multicast/broadcast never arrive (iOS, filtered
    // hotspots). Failures degrade silently inside.
    final id = deviceId;
    if (id != null) {
      final discovery = LanDiscovery(
        deviceId: id,
        port: port,
        onPeer: (ip, peerPort) {
          try {
            _peerAddrs[ip] = (InternetAddress(ip), DateTime.now());
          } catch (_) {
            // Unparseable address from a broken mDNS responder — ignore.
          }
        },
      );
      _discovery = discovery;
      await discovery.start();
    }
  }

  @override
  Future<void> stop() async {
    await _discovery?.stop();
    _discovery = null;
    try {
      await _lock.invokeMethod('release');
    } catch (_) {}
    _socket?.close();
    _socket = null;
    await _data.close();
  }

  @override
  Future<void> send(Uint8List datagram) async {
    final s = _socket;
    if (s == null) return;
    // 1) Multicast — the efficient path when the network forwards it.
    try {
      s.send(datagram, _group, port);
    } catch (_) {}
    // 2) Limited broadcast — some Android vendors filter one but not the other.
    try {
      s.send(datagram, InternetAddress('255.255.255.255'), port);
    } catch (_) {}
    // 3) Unicast to every peer we've heard from recently — the reliable path
    //    when the AP/hotspot drops multicast AND broadcast between clients.
    final now = DateTime.now();
    _peerAddrs.removeWhere((_, v) => now.difference(v.$2) > _peerAddrTtl);
    for (final entry in _peerAddrs.values) {
      try {
        s.send(datagram, entry.$1, port);
      } catch (_) {}
    }
  }
}
