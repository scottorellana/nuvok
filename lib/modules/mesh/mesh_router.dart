// The heart of the mesh: receives datagrams from every transport, drops
// duplicates, relays messages for others (controlled flooding with a hop
// limit — same scheme LoRa mesh radios use), decrypts what belongs to our
// channels, persists history, and queues outgoing messages while nobody is
// in range (store-and-forward).
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'mesh_channel.dart';
import 'mesh_envelope.dart';
import 'mesh_store.dart';
import 'mesh_transport.dart';

class MeshEvent {
  MeshEvent({required this.envelope, required this.channel, required this.payload});
  final MeshEnvelope envelope;
  final MeshChannel channel;
  final Map<String, dynamic> payload;
}

class MeshRouter {
  MeshRouter({
    required this.deviceId,
    required List<MeshTransport> transports,
    required List<MeshChannel> channels,
    required this.store,
  })  : _transports = transports,
        _channels = channels;

  final String deviceId;
  final List<MeshTransport> _transports;
  final List<MeshChannel> _channels;
  final MeshStore store;

  static const int _seenCap = 500;
  static const Duration peerTimeout = Duration(seconds: 45);

  final _seen = <int>{};
  final _seenQueue = Queue<int>();
  final _peers = <String, DateTime>{}; // senderId → last heard
  final _events = StreamController<MeshEvent>.broadcast();
  final _outbox = <Uint8List>[];
  final _subs = <StreamSubscription<Uint8List>>[];

  Stream<MeshEvent> get events => _events.stream;
  int get outboxCount => _outbox.length;

  /// Known peers heard recently on any transport.
  Map<String, DateTime> get peers => {
        for (final e in _peers.entries)
          if (DateTime.now().difference(e.value) < peerTimeout) e.key: e.value,
      };

  bool get hasPeers => peers.isNotEmpty;

  /// Channels whose messages we can read (emergency is always implied).
  List<MeshChannel> get channels => List.unmodifiable(_channels);

  void addChannel(MeshChannel c) {
    if (_channels.any((x) => x.id == c.id)) return;
    _channels.add(c);
  }

  void removeChannel(String id) =>
      _channels.removeWhere((c) => c.id == id);

  Future<void> start() async {
    _outbox.addAll(store.loadOutbox());
    for (final t in _transports) {
      await t.start();
      _subs.add(t.onData.listen(_handleIncoming));
    }
  }

  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final t in _transports) {
      await t.stop();
    }
    store.saveOutbox(_outbox);
  }

  /// Marks a peer as recently heard (also called by tests and beacons).
  void notePeer(String senderId) {
    if (senderId == deviceId) return;
    _peers[senderId] = DateTime.now();
  }

  /// Sends an envelope to everyone in range; queues it if nobody is.
  Future<void> broadcast(MeshEnvelope env) async {
    _markSeen(env.msgId); // never re-process our own message
    final bytes = env.encode();
    if (!hasPeers) {
      _outbox.add(bytes);
      store.saveOutbox(_outbox);
      return;
    }
    await _sendAll(bytes);
  }

  /// Drains the store-and-forward queue (call when a peer appears).
  Future<void> flushOutbox() async {
    if (!hasPeers || _outbox.isEmpty) return;
    final pending = List.of(_outbox);
    _outbox.clear();
    store.saveOutbox(_outbox);
    for (final bytes in pending) {
      await _sendAll(bytes);
    }
  }

  Future<void> _sendAll(Uint8List bytes) async {
    for (final t in _transports) {
      try {
        await t.send(bytes);
      } catch (_) {
        // A transport failing must not take the mesh down.
      }
    }
  }

  bool _markSeen(int msgId) {
    if (_seen.contains(msgId)) return false;
    _seen.add(msgId);
    _seenQueue.add(msgId);
    while (_seenQueue.length > _seenCap) {
      _seen.remove(_seenQueue.removeFirst());
    }
    return true;
  }

  MeshChannel? _channelFor(String channelId) {
    if (channelId == MeshChannel.emergency.id) return MeshChannel.emergency;
    for (final c in _channels) {
      if (c.id == channelId) return c;
    }
    return null;
  }

  Future<void> _handleIncoming(Uint8List datagram) async {
    final env = MeshEnvelope.decode(datagram);
    if (env == null) return;
    if (env.senderId == deviceId) return; // our own flood came back
    if (!_markSeen(env.msgId)) return; // duplicate
    notePeer(env.senderId);

    // Relay for others: controlled flooding with decreasing hop limit.
    if (env.hopLimit > 0) {
      await _sendAll(env.withHop(env.hopLimit - 1).encode());
    }

    final channel = _channelFor(env.channelId);
    if (channel == null) return; // not ours — relayed above, nothing to read
    final payload = await openPayload(env.payload, channel);
    if (payload == null) return; // wrong key or corrupt

    if (env.type != MeshType.beacon) {
      store.appendMessage(channel.id, {
        ...payload,
        '_from': env.senderId,
        '_name': env.senderName,
        '_type': env.type.name,
        '_ts': env.timestampMs,
      });
    }
    _events.add(MeshEvent(envelope: env, channel: channel, payload: payload));
  }
}
