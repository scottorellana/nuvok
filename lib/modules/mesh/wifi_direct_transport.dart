// WiFi Direct / Apple Multipeer transport for Prepper Mesh.
//
// Where the LAN transport needs an existing WiFi network (router or hotspot)
// and BLE is short-range/low-bandwidth, WiFi Direct gives device-to-device
// WiFi at full bandwidth with no infrastructure at all — the right path for
// moving big map tiles or media offline between two nearby Prepper Pads.
//
// Platform coverage:
//   • Android — [nearby_connections] (Google Nearby Connections over WiFi
//     Direct + BLE discovery). The only mature, maintained Flutter plugin for
//     Android P2P without a router.
//   • iOS / macOS — Apple platforms stay inactive here; LAN and BLE cover
//     Apple without advertising WiFi Direct support.
//   • Windows / Linux / Web — not supported; transport stays inactive.
//
// Graceful degradation follows the same pattern as LoraTransport: when the
// platform isn't supported or the API reports no adapter, [available] is false
// and the mesh simply doesn't offer WiFi Direct — LAN/BLE keep working.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import 'mesh_transport.dart';

/// Strategy: P2P_CLUSTER (star topology, best for battery + throughput).
const Strategy _kStrategy = Strategy.P2P_CLUSTER;

/// Wraps the nearby_connections API so transport logic can run against a fake
/// in tests.
abstract class WifiDirectLink {
  /// True on a supported platform with the plugin available.
  bool get available;

  /// Begins advertising + discovery. Returns true on success.
  Future<bool> start(String userName);

  /// Stops advertising + discovery and disconnects all endpoints.
  Future<void> stop();

  /// Stream of endpoints that just connected to us.
  Stream<String> get onConnected;

  /// Stream of endpoints that disconnected.
  Stream<String> get onDisconnected;

  /// Stream of raw payload bytes received from any endpoint.
  Stream<Uint8List> get onPayload;

  /// Sends [bytes] to [endpointId]. Returns true on success.
  Future<bool> send(String endpointId, Uint8List bytes);
}

/// Production link backed by the [NearbyConnections] plugin. Only active on
/// Android; on every other platform [available] is false and all methods are
/// inactive.
class NearbyConnectionsLink implements WifiDirectLink {
  final _connected = StreamController<String>.broadcast();
  final _disconnected = StreamController<String>.broadcast();
  final _payload = StreamController<Uint8List>.broadcast();
  bool _started = false;

  @override
  bool get available => defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<String> get onConnected => _connected.stream;

  @override
  Stream<String> get onDisconnected => _disconnected.stream;

  @override
  Stream<Uint8List> get onPayload => _payload.stream;

  @override
  Future<bool> start(String userName) async {
    if (!available || _started) return available && _started;
    try {
      final adv = await Nearby().startAdvertising(
        userName,
        _kStrategy,
        onConnectionInitiated: (id, info) {
          // Accept any Prepper Pad; the network name above is the gate.
          Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (eid, payload) {
              if (payload.type == PayloadType.BYTES) {
                _payload.add(Uint8List.fromList(payload.bytes!));
              }
            },
            onPayloadTransferUpdate: (_, __) {},
          ).then((ok) {
            if (ok) _connected.add(id);
          });
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _connected.add(id);
          } else {
            _disconnected.add(id);
          }
        },
        onDisconnected: (id) => _disconnected.add(id),
      );
      if (!adv) return false;
      final disc = await Nearby().startDiscovery(
        userName,
        _kStrategy,
        onEndpointFound: (id, name, serviceId) {
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: (eid, info) {
              Nearby().acceptConnection(
                eid,
                onPayLoadRecieved: (_, payload) {
                  if (payload.type == PayloadType.BYTES) {
                    _payload.add(Uint8List.fromList(payload.bytes!));
                  }
                },
                onPayloadTransferUpdate: (_, __) {},
              ).then((ok) {
                if (ok) _connected.add(eid);
              });
            },
            onConnectionResult: (eid, status) {
              if (status == Status.CONNECTED) {
                _connected.add(eid);
              }
            },
            onDisconnected: (eid) => _disconnected.add(eid),
          );
        },
        onEndpointLost: (_) {},
      );
      _started = disc;
      return _started;
    } catch (_) {
      _started = false;
      return false;
    }
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    try {
      await Nearby().stopAllEndpoints();
    } catch (_) {}
  }

  @override
  Future<bool> send(String endpointId, Uint8List bytes) async {
    if (!_started) return false;
    try {
      await Nearby().sendBytesPayload(endpointId, bytes);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// WiFi Direct mesh transport. Inactive on every platform except Android.
class WifiDirectTransport implements MeshTransport {
  WifiDirectTransport({WifiDirectLink? link})
      : _link = link ?? NearbyConnectionsLink();

  final WifiDirectLink _link;
  final _data = StreamController<Uint8List>.broadcast();
  final _endpoints = <String>{};
  StreamSubscription<String>? _connectSub;
  StreamSubscription<String>? _disconnectSub;
  StreamSubscription<Uint8List>? _payloadSub;
  bool _running = false;

  /// True on Android with the plugin available.
  bool get available => _link.available;

  @override
  String get name => 'wifi-direct';

  @override
  Stream<Uint8List> get onData => _data.stream;

  @override
  Future<void> start() async {
    if (_running || !available) return;
    _running = true;
    // Subscribe BEFORE native start: Nearby can report an endpoint immediately
    // during advertising/discovery. Missing that first event leaves emergency
    // devices visible but unable to send until a restart.
    _connectSub = _link.onConnected.listen(_endpoints.add);
    _disconnectSub = _link.onDisconnected.listen((id) {
      _endpoints.remove(id);
    });
    _payloadSub = _link.onPayload.listen(_data.add);
    final ok = await _link.start('prepper-pad');
    if (!ok) {
      _running = false;
      await _connectSub?.cancel();
      await _disconnectSub?.cancel();
      await _payloadSub?.cancel();
      _connectSub = _disconnectSub = _payloadSub = null;
      return;
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _connectSub?.cancel();
    await _disconnectSub?.cancel();
    await _payloadSub?.cancel();
    _connectSub = _disconnectSub = _payloadSub = null;
    _endpoints.clear();
    await _link.stop();
  }

  @override
  Future<void> send(Uint8List datagram) async {
    if (!_running) return;
    for (final id in List.of(_endpoints)) {
      try {
        await _link.send(id, datagram);
      } catch (_) {
        // One endpoint failing must not abort the others.
      }
    }
  }
}
