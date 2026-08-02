// The mesh, assembled: identity + channels + transports + router, plus the
// behaviors the UI cares about — chat, presence beacons, SOS broadcasting on
// the always-listened emergency channel, and periodic position sharing that
// feeds the Maps module.
import 'dart:async';
import 'dart:io';
import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/nuvok_library.dart';
import '../emergency/sos_alarm.dart';
import '../maps/location_service.dart';
import '../maps/map_overlays.dart';
import 'ble_transport.dart';
import 'lan_transport.dart';
import 'lora_ble_uart.dart';
import 'lora_transport.dart';
import 'mesh_channel.dart';
import 'mesh_envelope.dart';
import 'sos_receipt.dart';
import 'mesh_identity.dart';
import 'mesh_power_controller.dart';
import 'mesh_router.dart';
import 'mesh_store.dart';
import 'mesh_transport.dart';
import 'position_store.dart';
import 'transport_health.dart';
import 'voice_note.dart';
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
      _dirPath ??= '${NuvokLibrary.instance.root.path}/mesh';

  MeshIdentity? identity;
  MeshRouter? _router;
  MeshStore? _store;
  Timer? _beaconTimer;
  Timer? _sosTimer;
  Timer? _positionTimer;
  final _discoveryTimers = <Timer>[];
  StreamSubscription<MeshEvent>? _eventsSub;

  // One stable stream for the whole app: incoming router events and local
  // echoes of what we send, surviving router restarts.
  final _events = StreamController<MeshEvent>.broadcast();
  Stream<MeshEvent> get events => _events.stream;

  final ValueNotifier<bool> running = ValueNotifier(false);
  final ValueNotifier<bool> sosActive = ValueNotifier(false);

  /// Cuántos vecinos DISTINTOS han confirmado haber recibido mi SOS activo.
  /// 0 = nadie lo ha acusado todavía; la UI no debe fingir lo contrario.
  final ValueNotifier<int> sosHeardBy = ValueNotifier(0);
  final SosReceipts sosReceipts = SosReceipts();
  int? _lastSosMsgId;
  final ValueNotifier<bool> sharingPosition = ValueNotifier(false);
  final ValueNotifier<int> peerCount = ValueNotifier(0);
  final ValueNotifier<int> queuedCount = ValueNotifier(0);
  String? sosNote;

  /// Salud agregada de todos los transportes, con pares por transporte.
  /// La UI (banner + asistente de conexión) observa esto.
  final ValueNotifier<List<TransportHealth>> transportHealths =
      ValueNotifier(const []);
  final _healthListeners = <ValueNotifier<TransportHealth>, VoidCallback>{};
  List<MeshTransport> _activeTransports = const [];

  MeshStore get store => _store ??= MeshStore(dirPath);

  List<MeshChannel> get channels => _router?.channels ?? _channelsFromDisk();

  bool get hasIdentity => (identity ??= MeshIdentity.load(dirPath)) != null;

  /// Boot the mesh with zero setup: mint an automatic identity on first run,
  /// then start. Called at app launch so EVERY Nuvok is discoverable
  /// from the moment it opens — nobody is invisible for not having configured
  /// anything. The user can still rename the device later in Comunicación.
  Future<void> ensureStartedAuto() async {
    identity ??= MeshIdentity.ensureAuto(dirPath);
    await start();
  }

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
  static List<MeshTransport> defaultTransports({String? deviceId}) {
    final list = <MeshTransport>[LanTransport(deviceId: deviceId)];
    final ble = BleTransport();
    if (ble.available) list.add(ble);
    final wifi = WifiDirectTransport();
    if (wifi.available) list.add(wifi);
    // LoRa is opt-in: only wired when the user has paired a radio (persisted
    // flag). Included via the real BLE-UART driver, which connects to a
    // Nordic-UART LoRa module on start; if none is found it no-ops and the
    // other transports carry the mesh.
    if (loraEnabled) {
      list.add(LoraTransport(link: BleUartLoraDriver()));
    }
    return list;
  }

  /// Whether the user has enabled the LoRa long-range radio. Persisted so it
  /// survives restarts. Toggling restarts the mesh so the transport list is
  /// rebuilt with/without LoRa.
  static bool get loraEnabled =>
      NuvokLibrary.instance.settings['meshLoraEnabled'] == true;

  Future<void> setLoraEnabled(bool enabled) async {
    await NuvokLibrary.instance.saveSetting('meshLoraEnabled', enabled);
    if (running.value) {
      await stop();
      await start();
    }
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
    // Radio consciente de la batería + servicio de segundo plano (Android):
    // sin esto la radio escanea a máxima potencia siempre y el SOS de un
    // vecino solo llega con la app abierta.
    MeshPowerController.instance.start();
    unawaited(MeshPowerController.instance.startBackgroundIfEnabled());
    try {
      identity ??= MeshIdentity.load(dirPath);
      final id = identity;
      if (id == null) return; // UI must onboard first
      final transports =
          _transportsOverride ?? defaultTransports(deviceId: id.id);
      _activeTransports = transports;
      final router = MeshRouter(
        deviceId: id.id,
        transports: transports,
        channels: _channelsFromDisk(),
        store: store,
      );
      _router = router;
      await router.start();
      _wireHealth(router);
      _eventsSub = router.events.listen((e) {
        _events.add(e);
        _onEvent(e);
      });
      _scheduleBeaconTick(router);
      // Iniciar timer de cleanup de ACKs
      _startAckCleanupTimer();
      // Retransmit unacked chats every few seconds so a lost datagram is
      // resent until the peer confirms — reliable delivery over lossy WiFi.
      _retryTimer?.cancel();
      _retryTimer =
          Timer.periodic(const Duration(seconds: 3), (_) => _retryUnacked());
      running.value = true;
      await _sendBeacon();
      _triggerDiscoveryBurst();
      _listenConnectivity();
    } finally {
      _starting = false;
    }
  }

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  /// Suscribe la agregación a cada transporte que reporta salud y publica el
  /// estado combinado inicial.
  void _wireHealth(MeshRouter router) {
    for (final t in _activeTransports) {
      if (t is HealthReporting) {
        final notifier = (t as HealthReporting).health;
        void listener() => _publishHealth(router);
        notifier.addListener(listener);
        _healthListeners[notifier] = listener;
      }
    }
    _publishHealth(router);
  }

  void _publishHealth(MeshRouter router) {
    transportHealths.value = [
      for (final t in _activeTransports)
        (t is HealthReporting
                ? (t as HealthReporting).health.value
                : TransportHealth(
                    name: t.name, state: TransportState.searching))
            .copyWith(peers: router.peersVia(t.name)),
    ];
  }

  /// Watch connectivity so a grid/WiFi drop instantly relaunches discovery.
  /// Skipped under test (no override, no platform channel) and never fatal.
  void _listenConnectivity() {
    if (_transportsOverride != null) return; // test mode: no platform channel
    _connSub?.cancel();
    try {
      _connSub = Connectivity().onConnectivityChanged.listen((results) {
        final offline = results.isEmpty ||
            results.every((r) => r == ConnectivityResult.none);
        if (offline) onConnectivityLost();
      }, onError: (_) {});
    } catch (_) {
      // No connectivity plugin on this platform — the periodic beacon still
      // forms the mesh; we just lose the instant-on-drop optimization.
    }
  }

  /// Fires an immediate beacon plus a few quick follow-ups so a peer already
  /// nearby is found in ~1s instead of waiting up to a full beacon cycle.
  /// Used at startup AND whenever internet drops (see [onConnectivityLost]) —
  /// the moment neighbors most need to find each other fast.
  void _triggerDiscoveryBurst() {
    if (!running.value) return;
    _sendBeacon();
    for (final t in _discoveryTimers) {
      t.cancel();
    }
    _discoveryTimers.clear();
    for (final ms in const [400, 1200, 3000, 6000, 12000]) {
      _discoveryTimers.add(
        Timer(Duration(milliseconds: ms), () {
          if (running.value) _sendBeacon();
        }),
      );
    }
  }

  /// Call when the device loses internet connectivity. In an emergency the
  /// grid often dies first — the instant it does, every Nuvok relaunches
  /// discovery so the local mesh forms in seconds without any action.
  void onConnectivityLost() {
    if (!running.value) return;
    _triggerDiscoveryBurst();
  }

  Future<void> stop() async {
    _beaconTimer?.cancel();
    _sosTimer?.cancel();
    _positionTimer?.cancel();
    _ackCleanupTimer?.cancel();
    _retryTimer?.cancel();
    for (final t in _discoveryTimers) {
      t.cancel();
    }
    _discoveryTimers.clear();
    _beaconTimer =
        _sosTimer = _positionTimer = _ackCleanupTimer = _retryTimer = null;
    await _eventsSub?.cancel();
    _eventsSub = null;
    await _connSub?.cancel();
    _connSub = null;
    for (final entry in _healthListeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _healthListeners.clear();
    _activeTransports = const [];
    transportHealths.value = const [];
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
    // MeshEnvelope.sealed liga el header (remitente, tipo, timestamp) al
    // ciphertext como AAD: alterar el header en tránsito invalida el mensaje.
    return MeshEnvelope.sealed(
      msgId: MeshEnvelope.newMsgId(),
      channelId: channel.id,
      senderId: id.id,
      senderName: id.name,
      type: type,
      hopLimit: hopLimit,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      body: payload,
      channel: channel,
    );
  }

  /// Beacon cadence: fast while others are around (presence must stay
  /// fresh — peerTimeout is 45s), slow when alone (battery: the radio still
  /// wakes for incoming, and the discovery burst re-fires on start/resume).
  static Duration beaconInterval({required bool peersNearby}) =>
      peersNearby ? const Duration(seconds: 15) : const Duration(seconds: 60);

  /// One beacon tick that reschedules itself at the adaptive interval.
  void _scheduleBeaconTick(MeshRouter router) {
    _beaconTimer?.cancel();
    _beaconTimer =
        Timer(beaconInterval(peersNearby: router.peers.isNotEmpty), () {
      if (!running.value || _router != router) return;
      _sendBeacon();
      peerCount.value = router.peers.length;
      queuedCount.value = router.outboxCount;
      // También republicar la salud: sin esto, cuando un par expira en
      // silencio (LAN no emite desconexión) los healths quedan congelados
      // con peers>0 y el asistente devuelve cero pasos para siempre.
      _publishHealth(router);
      router.flushOutbox();
      _scheduleBeaconTick(router);
    });
  }

  Future<void> _sendBeacon() async {
    final router = _router;
    if (identity == null || router == null) return;
    try {
      // Beacons skip the outbox: presence only matters live.
      await router.sendNow(await _envelope(
          MeshChannel.emergency, MeshType.beacon, {'n': identity!.name},
          hopLimit: 1));
    } catch (_) {
      // A failing radio must never abort start() or a beacon timer: the
      // other transports keep the mesh alive (this killed iOS in the field).
    }
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

  /// Chat messages we sent that are still awaiting a delivery ACK. Keeps the
  /// full envelope so we can RETRANSMIT it — UDP over WiFi loses packets, so
  /// "sent once" is not "delivered". We resend until a peer ACKs or we hit the
  /// attempt cap.
  final Map<int, _PendingChat> _pendingAcks = {};

  /// Total sends (initial + retransmits) before we give up on an ACK. The
  /// message still shows a single ✓ (sent) if never confirmed.
  static const int maxChatSends = 5;

  /// msgIds confirmed as delivered. Bounded by [_confirmedCap] so a long
  /// session never leaks memory: once the cap is reached, the oldest entries
  /// are evicted (they are long-delivered and no longer actionable).
  final Set<int> _confirmedAcks = {};
  final Queue<int> _confirmedQueue = Queue();
  static const int _confirmedCap = 500;

  /// Notifier for UI to observe ACK changes (for ✓✓ display).
  final ValueNotifier<int> ackTick = ValueNotifier(0);

  /// Timer para cleanup de ACKs expirados.
  Timer? _ackCleanupTimer;

  /// Timer that retransmits unacknowledged chats.
  Timer? _retryTimer;

  /// Limpia ACKs pendientes que expiraron (más de 5 minutos sin confirmar).
  /// Llamado periódicamente para evitar memoria usada por mensajes perdidos.
  void _cleanupExpiredAcks() {
    final expired = <int>[];
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    for (final entry in _pendingAcks.entries) {
      if (entry.value.firstSent.isBefore(cutoff)) {
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

  /// Retransmits every chat still awaiting an ACK, up to [maxChatSends] total
  /// sends each. This is what makes delivery reliable over lossy WiFi: a
  /// dropped datagram is simply resent a few seconds later until the peer
  /// confirms receipt.
  Future<void> _retryUnacked() async {
    final router = _router;
    if (router == null || _pendingAcks.isEmpty) return;
    for (final pending in _pendingAcks.values.toList()) {
      if (pending.sends >= maxChatSends) continue;
      pending.sends++;
      pending.lastSent = DateTime.now();
      await router.sendNow(pending.env); // immediate, ungated re-send
    }
  }

  /// Test hook: run one retransmit pass synchronously.
  @visibleForTesting
  Future<void> retryUnackedForTest() => _retryUnacked();

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
    // Track for ACK + retransmit: keep the envelope so we can resend it until
    // a peer confirms receipt (UDP over WiFi drops packets).
    _pendingAcks[env.msgId] = _PendingChat(env);
    _events.add(MeshEvent(envelope: env, channel: channel, payload: payload));
    await router.broadcast(env);
    queuedCount.value = router.outboxCount;
  }

  /// Checks if a chat message [msgId] was acknowledged by a peer.
  bool isDelivered(int msgId) => _confirmedAcks.contains(msgId);

  /// Envía un clip de voz por el mesh — el walkie-talkie sin internet.
  /// Reutiliza broadcast + outbox: si no hay nadie al alcance, el clip sale
  /// cuando aparezca un par. Devuelve false si el audio excede el límite.
  Future<bool> sendVoice(
      MeshChannel channel, Uint8List audio, int durationMs) async {
    final router = _router;
    final id = identity;
    if (id == null || router == null) return false;
    final payload = encodeVoicePayload(audio, durationMs);
    if (payload == null) return false;
    final env = await _envelope(channel, MeshType.voice, payload);
    store.appendMessage(channel.id, {
      ...payload,
      '_from': id.id,
      '_name': id.name,
      '_type': MeshType.voice.name,
      '_ts': env.timestampMs,
      '_msgId': env.msgId,
    });
    // Mismo contrato de entrega que el chat: ✓ al enviar, ✓✓ con el ACK, y
    // retransmisión hasta que un par confirme.
    _pendingAcks[env.msgId] = _PendingChat(env);
    _events.add(MeshEvent(envelope: env, channel: channel, payload: payload));
    await router.broadcast(env);
    queuedCount.value = router.outboxCount;
    return true;
  }

  /// Comparte un overlay táctico (GeoJSON Feature) al canal de emergencia:
  /// "puente caído aquí" marcado por un vecino aparece en el mapa de TODOS.
  Future<bool> shareOverlayFeature(Map<String, dynamic> feature) async {
    final router = _router;
    final id = identity;
    if (id == null || router == null) return false;
    final env = await _envelope(
        MeshChannel.emergency, MeshType.overlay, {'f': feature},
        hopLimit: 5);
    await router.broadcast(env);
    queuedCount.value = router.outboxCount;
    return true;
  }

  /// Escribe (una sola vez) los bytes de un clip a
  /// `<mesh>/voice/<msgId>.m4a` y devuelve el archivo — just_audio
  /// reproduce desde disco, no desde memoria.
  Future<File> voiceFile(int msgId, VoiceNote note) async {
    final dir = Directory('$dirPath/voice');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final f = File('${dir.path}/$msgId.m4a');
    if (!f.existsSync()) {
      await f.writeAsBytes(note.audio, flush: true);
    }
    return f;
  }

  /// SOS: broadcast position+note on the open emergency channel now and
  /// every minute until cancelled. Reaches every Nuvok in range,
  /// authenticated or not.
  Future<void> startSos({String note = ''}) async {
    sosNote = note;
    sosActive.value = true;
    MeshPowerController.instance.setSosActive(true);
    await _broadcastSos();
    _sosTimer?.cancel();
    _sosTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _broadcastSos());
  }

  /// Burst final de posición: cuando la batería agoniza, un último SOS con
  /// coordenadas por TODOS los transportes + registro en disco por si el
  /// teléfono se apaga y los rescatistas lo recuperan después.
  Future<bool> sendLastPositionBurst({
    required double lat,
    required double lon,
    String note = '',
  }) async {
    final router = _router;
    if (identity == null || router == null) return false;
    try {
      File('$dirPath/last_position.json').writeAsStringSync(
          '{"lat": $lat, "lon": $lon, "note": "$note", '
          '"ts": ${DateTime.now().millisecondsSinceEpoch}}');
    } catch (_) {}
    await router.broadcast(await _envelope(
      MeshChannel.emergency,
      MeshType.sos,
      {'note': note, 'lat': lat, 'lon': lon},
      hopLimit: 5,
    ));
    return true;
  }

  Future<void> _broadcastSos() async {
    final router = _router;
    if (identity == null || router == null || !sosActive.value) return;
    final fix = await LocationService.current();
    final env = await _envelope(
      MeshChannel.emergency,
      MeshType.sos,
      {
        'note': sosNote ?? '',
        if (fix.isOk) 'lat': fix.position!.latitude,
        if (fix.isOk) 'lon': fix.position!.longitude,
        if (fix.isOk) 'acc': fix.position!.accuracy,
      },
      hopLimit: 5, // let an SOS travel as far as the mesh reaches
    );
    _lastSosMsgId = env.msgId;
    sosReceipts.registerSent('${env.senderId}:${env.msgId}');
    await router.broadcast(env);
  }

  Future<void> cancelSos() async {
    _sosTimer?.cancel();
    _sosTimer = null;
    sosActive.value = false;
    sosHeardBy.value = 0;
    final last = _lastSosMsgId;
    if (last != null) sosReceipts.clear('${identity?.id}:$last');
    _lastSosMsgId = null;
    MeshPowerController.instance.setSosActive(false);
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
    // Refrescar pares-por-transporte al oír tráfico (beacon, chat, SOS…).
    final r = _router;
    if (r != null) _publishHealth(r);
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
          // Confirmar al emisor que su SOS FUE OÍDO. Sin esto, quien pide
          // auxilio no sabe si quedarse donde está o gastar sus últimas
          // fuerzas caminando a buscar ayuda. El ACK cruza el relevo
          // (hopLimit 3) porque el SOS también se relevó.
          _sendAck(e, hopLimit: sosAckHopLimit);
          MeshPowerController.instance.boostForIncomingSos();
          SosAlarmController.instance.trigger(
            id: e.envelope.senderId,
            fromName: e.envelope.senderName,
            note: e.payload['note'] as String?,
          );
        }
        break;
      case MeshType.sosCancel:
        PositionStore.instance.clearSos(e.envelope.senderId);
        // Quitar SOLO a quien canceló. Antes se comparaba por senderName y se
        // llamaba a silence(): dos vecinos llamados igual se confundían, y
        // cancelar el de uno callaba el de todos los demás.
        SosAlarmController.instance.dismiss(e.envelope.senderId);
        break;
      case MeshType.chat:
        // Send an ACK back so the sender knows the message was delivered.
        _sendAck(e);
        break;
      case MeshType.overlay:
        // Overlay táctico entrante → directo al mapa (upsert idempotente).
        final f = e.payload['f'];
        if (f is Map) {
          final o = MapOverlay.fromFeature(f.cast<String, dynamic>());
          if (o != null) unawaited(OverlayStore.instance.upsert(o));
        }
        break;
      case MeshType.voice:
        // Un clip de voz entrante: confirmar entrega igual que un chat y
        // cachear el audio a disco para reproducirlo sin decodificar base64
        // cada vez.
        if (e.envelope.senderId != identity?.id) _sendAck(e);
        final note = decodeVoicePayload(e.payload);
        if (note != null) {
          unawaited(voiceFile(e.envelope.msgId, note));
        }
        break;
      case MeshType.ack:
        // Mark the original message as delivered.
        final ackedId = (e.payload['ack'] as num?)?.toInt();
        if (ackedId != null) {
          // ¿Confirma alguno de MIS SOS? Se cuenta por vecino distinto.
          sosReceipts.onAck(
            ackedMsgId: '${identity?.id}:$ackedId',
            fromPeer: e.envelope.senderId,
          );
          sosHeardBy.value =
              sosReceipts.confirmationsFor('${identity?.id}:$_lastSosMsgId');
        }
        if (ackedId != null && _pendingAcks.containsKey(ackedId)) {
          _pendingAcks.remove(ackedId);
          _confirmedAcks.add(ackedId);
          _confirmedQueue.add(ackedId);
          while (_confirmedQueue.length > _confirmedCap) {
            _confirmedAcks.remove(_confirmedQueue.removeFirst());
          }
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
  Future<void> _sendAck(MeshEvent original, {int hopLimit = 1}) async {
    final router = _router;
    final id = identity;
    if (id == null || router == null) return;
    // ACKs go on the same channel as the original message.
    final ackEnv = await _envelope(
      original.channel,
      MeshType.ack,
      {'ack': original.envelope.msgId},
      hopLimit: hopLimit, // 1 para chat (vecino directo); más para SOS
    );
    await router.sendNow(ackEnv);
  }
}

/// A chat we sent that's still awaiting a delivery ACK. Holds the envelope so
/// it can be retransmitted, plus how many times we've sent it.
class _PendingChat {
  _PendingChat(this.env)
      : firstSent = DateTime.now(),
        lastSent = DateTime.now(),
        sends = 1; // the initial broadcast counts as the first send

  final MeshEnvelope env;
  final DateTime firstSent;
  DateTime lastSent;
  int sends;
}
