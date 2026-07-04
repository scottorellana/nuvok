// The mesh, assembled: identity + channels + transports + router, plus the
// behaviors the UI cares about — chat, presence beacons, SOS broadcasting on
// the always-listened emergency channel, and periodic position sharing that
// feeds the Maps module.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/prepper_library.dart';
import '../emergency/sos_alarm.dart';
import '../maps/location_service.dart';
import 'ble_transport.dart';
import 'lan_transport.dart';
import 'mesh_channel.dart';
import 'mesh_envelope.dart';
import 'mesh_identity.dart';
import 'mesh_router.dart';
import 'mesh_store.dart';
import 'mesh_transport.dart';
import 'position_store.dart';
import 'wifi_direct_transport.dart';

class MeshService {
  MeshService._();
  static final MeshService instance = MeshService._();

  /// Isolated instance for tests: own dir, fake transports, no GPS timers.
  @visibleForTesting
  factory MeshService.forTest({
    required String dirPath,
    required List<MeshTransport> transports,
    required MeshIdentity identity,
  }) {
    final s = MeshService._();
    s._dirPath = dirPath;
    s._transportsOverride = transports;
    s.identity = identity..save(dirPath);
    return s;
  }

  String? _dirPath;
  List<MeshTransport>? _transportsOverride;

  String get dirPath =>
      _dirPath ??= '${PrepperLibrary.instance.root.path}/mesh';

  MeshIdentity? identity;
  MeshRouter? _router;
  MeshStore? _store;
  Timer? _beaconTimer;
  Timer? _sosTimer;
  Timer? _positionTimer;
  StreamSubscription<MeshEvent>? _eventsSub;

  // One stable stream for the whole app: incoming router events and local
  // echoes of what we send, surviving router restarts.
  final _events = StreamController<MeshEvent>.broadcast();
  Stream<MeshEvent> get events => _events.stream;

  final ValueNotifier<bool> running = ValueNotifier(false);
  final ValueNotifier<bool> sosActive = ValueNotifier(false);
  final ValueNotifier<bool> sharingPosition = ValueNotifier(false);
  final ValueNotifier<int> peerCount = ValueNotifier(0);
  final ValueNotifier<int> queuedCount = ValueNotifier(0);
  String? sosNote;

  MeshStore get store => _store ??= MeshStore(dirPath);

  List<MeshChannel> get channels => _router?.channels ?? _channelsFromDisk();

  bool get hasIdentity => (identity ??= MeshIdentity.load(dirPath)) != null;

  Future<void> setIdentity(String name) async {
    final current = identity ?? MeshIdentity.load(dirPath);
    if (current == null) {
      identity = MeshIdentity.create(name)..save(dirPath);
    } else {
      identity = current
        ..name = name
        ..save(dirPath);
    }
    if (running.value) {
      await stop();
    }
    await start();
  }

  List<MeshChannel> _channelsFromDisk() => [
        for (final j in store.loadChannels())
          if (MeshChannel.fromJson(j) case final MeshChannel c) c,
      ];

  /// Transports wired in by default: LAN always, plus BLE and WiFi Direct on
  /// platforms where their adapters report available. Each transport
  /// self-degrades to a no-op if its hardware is missing, so including them is
  /// always safe. Kept as a method (not a constant) so availability is checked
  /// freshly every time the mesh starts.
  static List<MeshTransport> defaultTransports() {
    final list = <MeshTransport>[LanTransport()];
    final ble = BleTransport();
    if (ble.available) list.add(ble);
    final wifi = WifiDirectTransport();
    if (wifi.available) list.add(wifi);
    return list;
  }

  void _saveChannels() {
    store.saveChannels([
      for (final c in _router?.channels ?? _channelsFromDisk()) c.toJson(),
    ]);
  }

  bool _starting = false;

  Future<void> start() async {
    if (running.value || _starting) return;
    _starting = true;
    try {
      identity ??= MeshIdentity.load(dirPath);
      final id = identity;
      if (id == null) return; // UI must onboard first
      final router = MeshRouter(
        deviceId: id.id,
        transports: _transportsOverride ?? defaultTransports(),
        channels: _channelsFromDisk(),
        store: store,
      );
      _router = router;
      await router.start();
      _eventsSub = router.events.listen((e) {
        _events.add(e);
        _onEvent(e);
      });
      _beaconTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _sendBeacon();
        peerCount.value = router.peers.length;
        queuedCount.value = router.outboxCount;
        router.flushOutbox();
      });
      // Iniciar timer de cleanup de ACKs
      _startAckCleanupTimer();
      running.value = true;
      await _sendBeacon();
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    _beaconTimer?.cancel();
    _sosTimer?.cancel();
    _positionTimer?.cancel();
    _ackCleanupTimer?.cancel();
    _beaconTimer = _sosTimer = _positionTimer = _ackCleanupTimer = null;
    await _eventsSub?.cancel();
    _eventsSub = null;
    await _router?.stop();
    _router = null;
    running.value = false;
    sosActive.value = false;
    sharingPosition.value = false;
  }

  Future<MeshEnvelope> _envelope(
    MeshChannel channel,
    MeshType type,
    Map<String, dynamic> payload, {
    int hopLimit = 3,
  }) async {
    final id = identity!;
    return MeshEnvelope(
      msgId: MeshEnvelope.newMsgId(),
      channelId: channel.id,
      senderId: id.id,
      senderName: id.name,
      type: type,
      hopLimit: hopLimit,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      payload: await sealPayload(payload, channel),
    );
  }

  Future<void> _sendBeacon() async {
    final router = _router;
    if (identity == null || router == null) return;
    // Beacons skip the outbox: presence only matters live.
    await router.sendNow(await _envelope(
        MeshChannel.emergency, MeshType.beacon, {'n': identity!.name},
        hopLimit: 1));
  }

  Future<void> joinChannel(MeshChannel c) async {
    final router = _router;
    if (router == null) {
      final existing = _channelsFromDisk();
      if (existing.any((x) => x.id == c.id)) return;
      store.saveChannels([...existing, c].map((x) => x.toJson()).toList());
      return;
    }
    router.addChannel(c);
    _saveChannels();
  }

  Future<void> leaveChannel(String channelId) async {
    final router = _router;
    if (router == null) {
      final remaining = [
        for (final c in _channelsFromDisk())
          if (c.id != channelId) c,
      ];
      store.saveChannels(remaining.map((c) => c.toJson()).toList());
      return;
    }
    router.removeChannel(channelId);
    _saveChannels();
  }

  /// msgIds of chat messages we sent, awaiting delivery confirmation.
  final Map<int, DateTime> _pendingAcks = {};

  /// msgIds confirmed as delivered (keyed by msgId → timestamp).
  final Set<int> _confirmedAcks = {};

  /// Notifier for UI to observe ACK changes (for ✓✓ display).
  final ValueNotifier<int> ackTick = ValueNotifier(0);

  /// Timer para cleanup de ACKs expirados.
  Timer? _ackCleanupTimer;

  /// Limpia ACKs pendientes que expiraron (más de 5 minutos sin confirmar).
  /// Llamado periódicamente para evitar memoria usada por mensajes perdidos.
  void _cleanupExpiredAcks() {
    final expired = <int>[];
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    for (final entry in _pendingAcks.entries) {
      if (entry.value.isBefore(cutoff)) {
        expired.add(entry.key);
      }
    }
    for (final id in expired) {
      _pendingAcks.remove(id);
      // Not confirmed = shown as "enviado" sin ✓✓
    }
    if (expired.isNotEmpty) {
      ackTick.value++; // Refresh UI
    }
  }

  /// Inicia el timer de cleanup de ACKs (llamado en start()).
  void _startAckCleanupTimer() {
    _ackCleanupTimer?.cancel();
    _ackCleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cleanupExpiredAcks(),
    );
  }

  /// Mantiene presencia activa cuando la app vuelve a primer plano.
  /// Llamado desde el lifecycle de la app.
  Future<void> onAppResumed() async {
    if (!running.value) return;
    await _sendBeacon();
    peerCount.value = _router?.peers.length ?? 0;
  }

  Future<void> sendChat(MeshChannel channel, String text) async {
    final router = _router;
    final id = identity;
    if (id == null || router == null || text.trim().isEmpty) return;
    final payload = {'text': text.trim()};
    final env = await _envelope(channel, MeshType.chat, payload);
    store.appendMessage(channel.id, {
      ...payload,
      '_from': id.id,
      '_name': id.name,
      '_type': MeshType.chat.name,
      '_ts': env.timestampMs,
      '_msgId': env.msgId, // lets the UI show ✓ (enviado) / ✓✓ (entregado)
    });
    // Track for ACK: this message is awaiting confirmation.
    _pendingAcks[env.msgId] = DateTime.now();
    _events.add(MeshEvent(envelope: env, channel: channel, payload: payload));
    await router.broadcast(env);
    queuedCount.value = router.outboxCount;
  }

  /// Checks if a chat message [msgId] was acknowledged by a peer.
  bool isDelivered(int msgId) => _confirmedAcks.contains(msgId);

  /// SOS: broadcast position+note on the open emergency channel now and
  /// every minute until cancelled. Reaches every Prepper Pad in range,
  /// authenticated or not.
  Future<void> startSos({String note = ''}) async {
    sosNote = note;
    sosActive.value = true;
    await _broadcastSos();
    _sosTimer?.cancel();
    _sosTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _broadcastSos());
  }

  Future<void> _broadcastSos() async {
    final router = _router;
    if (identity == null || router == null || !sosActive.value) return;
    final fix = await LocationService.current();
    await router.broadcast(await _envelope(
      MeshChannel.emergency,
      MeshType.sos,
      {
        'note': sosNote ?? '',
        if (fix.isOk) 'lat': fix.position!.latitude,
        if (fix.isOk) 'lon': fix.position!.longitude,
        if (fix.isOk) 'acc': fix.position!.accuracy,
      },
      hopLimit: 5, // let an SOS travel as far as the mesh reaches
    ));
  }

  Future<void> cancelSos() async {
    _sosTimer?.cancel();
    _sosTimer = null;
    sosActive.value = false;
    final router = _router;
    if (identity == null || router == null) return;
    await router.broadcast(await _envelope(
        MeshChannel.emergency, MeshType.sosCancel, {'ok': true},
        hopLimit: 5));
  }

  /// Periodically shares our GPS position on every joined channel so the
  /// group sees us on their offline map.
  Future<void> setSharePosition(bool enabled) async {
    sharingPosition.value = enabled;
    _positionTimer?.cancel();
    _positionTimer = null;
    if (!enabled) return;
    await _broadcastPosition();
    _positionTimer =
        Timer.periodic(const Duration(minutes: 2), (_) => _broadcastPosition());
  }

  Future<void> _broadcastPosition() async {
    final router = _router;
    if (identity == null || router == null) return;
    final fix = await LocationService.current();
    if (!fix.isOk) return;
    final payload = {
      'lat': fix.position!.latitude,
      'lon': fix.position!.longitude,
      'acc': fix.position!.accuracy,
    };
    for (final channel in router.channels) {
      await router
          .broadcast(await _envelope(channel, MeshType.position, payload));
    }
  }

  void _onEvent(MeshEvent e) {
    peerCount.value = _router?.peers.length ?? 0;
    queuedCount.value = _router?.outboxCount ?? 0;
    switch (e.envelope.type) {
      case MeshType.position:
      case MeshType.sos:
        final lat = (e.payload['lat'] as num?)?.toDouble();
        final lon = (e.payload['lon'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          PositionStore.instance.update(PeerPosition(
            id: e.envelope.senderId,
            name: e.envelope.senderName,
            lat: lat,
            lon: lon,
            time: DateTime.fromMillisecondsSinceEpoch(e.envelope.timestampMs),
            accuracy: (e.payload['acc'] as num?)?.toDouble(),
            isSos: e.envelope.type == MeshType.sos,
            sosNote: e.payload['note'] as String?,
          ));
        }
        // Trigger the SOS alarm for incoming distress signals.
        if (e.envelope.type == MeshType.sos &&
            e.envelope.senderId != identity?.id) {
          SosAlarmController.instance.trigger(
            fromName: e.envelope.senderName,
            note: e.payload['note'] as String?,
          );
        }
        break;
      case MeshType.sosCancel:
        PositionStore.instance.clearSos(e.envelope.senderId);
        // Silence the alarm if it was from this sender.
        if (SosAlarmController.instance.alarmFromName ==
            e.envelope.senderName) {
          SosAlarmController.instance.silence();
        }
        break;
      case MeshType.chat:
        // Send an ACK back so the sender knows the message was delivered.
        _sendAck(e);
        break;
      case MeshType.ack:
        // Mark the original message as delivered.
        final ackedId = (e.payload['ack'] as num?)?.toInt();
        if (ackedId != null && _pendingAcks.containsKey(ackedId)) {
          _pendingAcks.remove(ackedId);
          _confirmedAcks.add(ackedId);
          ackTick.value++;
        }
        break;
      case MeshType.beacon:
        // A peer just appeared — flush queued messages immediately so
        // they don't wait up to 15s for the next beacon timer tick.
        // Critical for emergency scenarios where every second counts.
        _router?.flushOutbox();
        break;
    }
  }

  /// Sends an ACK for a received chat message, confirming delivery.
  Future<void> _sendAck(MeshEvent original) async {
    final router = _router;
    final id = identity;
    if (id == null || router == null) return;
    // ACKs go on the same channel as the original message.
    final ackEnv = await _envelope(
      original.channel,
      MeshType.ack,
      {'ack': original.envelope.msgId},
      hopLimit: 1, // ACKs don't need to travel far
    );
    await router.sendNow(ackEnv);
  }
}
