// The heart of the mesh: receives datagrams from every transport, drops
// duplicates, relays messages for others (controlled flooding with a hop
// limit — same scheme LoRa mesh radios use), decrypts what belongs to our
// channels, persists history, and queues outgoing messages while nobody is
// in range (store-and-forward).
import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'mesh_channel.dart';
import 'mesh_diagnostics.dart';
import 'mesh_envelope.dart';
import 'relay_policy.dart';
import 'mesh_store.dart';
import 'sos_auth.dart';
import 'sos_carry.dart';
import 'mesh_transport.dart';

class MeshEvent {
  MeshEvent(
      {required this.envelope, required this.channel, required this.payload});
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
  // Low-RAM / offline-safe cap: if a device stays isolated for days, the
  // store-and-forward queue must not grow without bound in memory or disk.
  // Keep the newest messages because they are most actionable in the field.
  static const int maxOutboxDatagrams = 200;
  static const Duration peerTimeout = Duration(seconds: 45);

  final _seen = <int>{};
  final _seenQueue = Queue<int>();
  final _peers = <String, DateTime>{}; // senderId → last heard
  // Pares oídos recientemente POR TRANSPORTE — alimenta TransportHealth.peers
  // para que el banner pueda decir "3 dispositivos por Bluetooth".
  final _peersVia = <String, Map<String, DateTime>>{};
  final _events = StreamController<MeshEvent>.broadcast();
  final _outbox = <Uint8List>[];
  /// SOS ajenos que llevamos encima para entregarlos a quien llegue después.
  final _carry = SosCarry();

  /// Huellas de los SOS oídos, para decidir qué cancelaciones son legítimas.
  /// Las alimenta el propio store-and-forward al ver pasar cada SOS.
  SosCommitments get sosCommitments => _carry.commitments;
  /// Remitentes ya vistos: distinguir un vecino NUEVO de uno ya conocido.
  final _knownSenders = <String>{};
  final _subs = <StreamSubscription<Uint8List>>[];

  // Flood suppression (Meshtastic-style, scales to ~50 nodes): count copies
  // heard per msgId and schedule the relay after a random jitter. If the
  // network already repeated the message enough times while we waited, our
  // relay adds nothing but airtime — cancel it.
  /// Repeticiones DISTINTAS oídas por mensaje, identificadas por los saltos
  /// que le quedaban. Antes era un contador de datagramas: las
  /// tres radios de la app y las tres rutas de lan_transport entregaban la
  /// misma copia, el nodo creía que la red ya había repetido el mensaje y
  /// cancelaba su relevo — el SOS moría en el primer salto justo en la
  /// configuración normal de la app.
  final _heardCount = RelayHeardCounter();
  final _pendingRelays = <int, Timer>{};

  /// Test hook: overrides the relay jitter (production: random per type).
  @visibleForTesting
  Duration Function(MeshType type)? debugRelayJitter;

  Duration _relayJitter(MeshType type) {
    final custom = debugRelayJitter;
    if (custom != null) return custom(type);
    final r = Random();
    // SOS relays sooner and with less suppression: in an emergency, an extra
    // duplicate beats a lost cry for help.
    return type == MeshType.sos
        ? Duration(milliseconds: 20 + r.nextInt(60))
        : Duration(milliseconds: 50 + r.nextInt(250));
  }

  Stream<MeshEvent> get events => _events.stream;
  int get outboxCount => _outbox.length;

  /// Known peers heard recently on any transport.
  Map<String, DateTime> get peers => {
        for (final e in _peers.entries)
          if (DateTime.now().difference(e.value) < peerTimeout) e.key: e.value,
      };

  bool get hasPeers => peers.isNotEmpty;

  /// Pares vivos oídos por un transporte concreto ('ble', 'lan', …).
  ///
  /// Nota: cuenta el REMITENTE ORIGINAL del envelope, así que un mensaje de A
  /// relevado por B y oído por BLE registra a A como "alcanzable por BLE" —
  /// correcto para el asistente (A es alcanzable vía ese transporte a través
  /// del relevo), pero el desglose por transporte puede superar a los
  /// vecinos físicos directos.
  int peersVia(String transport) {
    final m = _peersVia[transport];
    if (m == null) return 0;
    final now = DateTime.now();
    m.removeWhere((_, heard) => now.difference(heard) >= peerTimeout);
    return m.length;
  }

  /// Channels whose messages we can read (emergency is always implied).
  List<MeshChannel> get channels => List.unmodifiable(_channels);

  void addChannel(MeshChannel c) {
    if (_channels.any((x) => x.id == c.id)) return;
    _channels.add(c);
  }

  void removeChannel(String id) => _channels.removeWhere((c) => c.id == id);

  Future<void> start() async {
    _outbox.addAll(store.loadOutbox());
    _trimOutboxToCap();
    for (final t in _transports) {
      // Subscribe BEFORE transport start. BLE/WiFi Direct/LAN fakes and some
      // real stacks can emit discovery/beacon payloads immediately during
      // start(); broadcast streams drop events with no listeners.
      _subs.add(t.onData.listen((d) => _handleIncoming(d, via: t.name)));
      await t.start();
    }
  }

  Future<void> stop() async {
    for (final t in _pendingRelays.values) {
      t.cancel();
    }
    _pendingRelays.clear();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final t in _transports) {
      await t.stop();
    }
    await _events.close();
    store.saveOutbox(_outbox);
  }

  /// Marks a peer as recently heard (also called by tests and beacons).
  void notePeer(String senderId) {
    if (senderId == deviceId) return;
    _peers[senderId] = DateTime.now();
  }

  /// Sends an envelope to everyone in range, and queues it for later if we
  /// haven't confirmed anyone is around yet.
  Future<void> broadcast(MeshEnvelope env) async {
    _markSeen(env.msgId); // never re-process our own message
    final bytes = env.encode();
    // ALWAYS put it on the wire immediately. multicast/broadcast reaches
    // anyone listening right now — even a peer whose beacon we haven't heard
    // yet. Gating this on `hasPeers` was a deadlock: if beacon reception was
    // flaky (very common — many WiFi APs and phone hotspots drop multicast
    // between clients), we never registered peers, so messages were queued
    // forever and never actually sent.
    await _sendAll(bytes);
    // If nobody is confirmed in range, ALSO keep it queued so it goes out
    // again the moment a peer's beacon appears (store-and-forward for peers
    // that were briefly out of range at send time). The receiver's dedup
    // makes the resulting best-effort redundancy harmless.
    if (!hasPeers) {
      _outbox.add(bytes);
      _trimOutboxToCap();
      store.saveOutbox(_outbox);
    }
  }

  /// Sends immediately on every transport, skipping the outbox — for
  /// presence beacons, which only matter live.
  Future<void> sendNow(MeshEnvelope env) async {
    _markSeen(env.msgId);
    await _sendAll(env.encode());
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

  void _trimOutboxToCap() {
    while (_outbox.length > maxOutboxDatagrams) {
      _outbox.removeAt(0);
    }
  }

  Future<void> _sendAll(Uint8List bytes) async {
    for (final t in _transports) {
      try {
        await t.send(bytes);
        MeshDiagnostics.instance.recordSent(t.name, bytes.length);
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
      // Evict the heard-count alongside the dedup entry so both stay bounded.
      final evicted = _seenQueue.removeFirst();
      _seen.remove(evicted);
      _heardCount.forget(evicted);
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

  Future<void> _handleIncoming(Uint8List datagram, {String? via}) async {
    if (via != null) {
      MeshDiagnostics.instance.recordReceived(via, datagram.length);
    }
    final env = MeshEnvelope.decode(datagram);
    if (env == null) return;
    if (env.senderId == deviceId) return; // our own flood came back
    if (via != null) {
      (_peersVia[via] ??= <String, DateTime>{})[env.senderId] = DateTime.now();
    }
    // Un relevo real llega con MENOS saltos; los ecos de un mismo envío
    // llegan todos con el mismo hopLimit.
    _heardCount.heard(msgId: env.msgId, hopLimit: env.hopLimit);
    notePeer(env.senderId);
    // Un vecino NUEVO: entregarle los SOS que venimos cargando. Así el
    // rescatista que pasa diez minutos tarde igual se entera.
    if (_knownSenders.add(env.senderId)) {
      final carried = _carry.datagramsToForward();
      if (carried.isNotEmpty) {
        MeshDiagnostics.instance
            .log('vecino nuevo: reenviando ${carried.length} SOS guardado(s)');
        for (final bytes in carried) {
          unawaited(_sendAll(bytes));
        }
      }
    }
    if (!_markSeen(env.msgId)) return; // duplicate: counted above, done

    // Guardar/soltar el SOS ajeno (la cancelación del mismo remitente lo
    // descarta: si ya está a salvo, seguir gritando su SOS es dañino).
    _carry.offer(env);

    // Relay for others: controlled flooding, but deferred by a random jitter
    // so dense meshes don't all shout at once — and cancelled if enough
    // copies were heard in the meantime (someone else already relayed).
    if (env.hopLimit > 0) {
      final relayBytes = env.withHop(env.hopLimit - 1).encode();
      _pendingRelays[env.msgId] = Timer(_relayJitter(env.type), () {
        _pendingRelays.remove(env.msgId);
        if (shouldRelay(
            heard: _heardCount.countFor(env.msgId),
            type: env.type == MeshType.sos
                ? RelayType.sos
                : RelayType.normal)) {
          _sendAll(relayBytes);
        }
      });
    }

    final channel = _channelFor(env.channelId);
    if (channel == null) return; // not ours — relayed above, nothing to read
    final payload = await openPayload(env.payload, channel, aad: env.aadBytes);
    if (payload == null) return; // wrong key, tampered header, or corrupt

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
