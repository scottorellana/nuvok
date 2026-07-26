// Bonjour/mDNS peer discovery for the LAN transport. This is the
// iOS-sanctioned path: raw multicast needs a special Apple entitlement, but
// Bonjour (NSBonjourServices in Info.plist) does not — so an iPhone finds
// peers via Bonjour and then talks plain unicast UDP, which is unrestricted.
// On Android/desktop it complements the existing multicast (some routers and
// phone hotspots filter multicast but forward mDNS).
import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

/// Keeps best-effort transports alive when a platform stream reports an
/// asynchronous error. iOS Bonjour can emit DefunctConnection after start().
StreamSubscription<T> listenWithoutFatalErrors<T>(
  Stream<T> stream,
  void Function(T event) onData,
) {
  return stream.listen(
    onData,
    onError: (Object _, StackTrace __) {},
    cancelOnError: false,
  );
}

/// Announces `_Nuvokpad._udp` (TXT: device id) and browses for the same
/// type. Every foreign resolved service triggers [onPeer] so the transport
/// can seed its unicast address book.
///
/// The resolution logic ([handleResolved]) is pure and unit-tested; the
/// bonsoir plumbing degrades silently on platforms without support, matching
/// the project-wide transport pattern.
class LanDiscovery {
  LanDiscovery({
    required this.deviceId,
    required this.port,
    required this.onPeer,
  });

  static const String serviceType = '_Nuvokpad._udp';

  final String deviceId;
  final int port;
  final void Function(String ip, int port) onPeer;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _eventsSub;
  final _known = <String>{}; // "id@ip" already reported

  /// Pure resolution logic: filter self and garbage, dedupe, report.
  void handleResolved(
      {required String id, required String ip, required int port}) {
    if (id.isEmpty || ip.isEmpty || port <= 0) return;
    if (id == deviceId) return; // our own announcement echoed back
    if (!_known.add('$id@$ip')) return; // same peer+ip already reported
    onPeer(ip, port);
  }

  Future<void> start() async {
    try {
      final service = BonsoirService(
        // The service name must be unique per device on the network; the
        // device id already is. TXT carries it for self-filtering.
        name: 'Nuvok-$deviceId',
        type: serviceType,
        port: port,
        attributes: {'id': deviceId},
      );
      final broadcast = BonsoirBroadcast(service: service);
      await broadcast.ready;
      await broadcast.start();
      _broadcast = broadcast;

      final discovery = BonsoirDiscovery(type: serviceType);
      await discovery.ready;
      final events = discovery.eventStream;
      if (events != null) {
        _eventsSub = listenWithoutFatalErrors(events, (event) {
          final s = event.service;
          if (s == null) return;
          if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
            s.resolve(discovery.serviceResolver);
          } else if (event.type ==
              BonsoirDiscoveryEventType.discoveryServiceResolved) {
            final resolved = s;
            final host =
                resolved is ResolvedBonsoirService ? (resolved.host ?? '') : '';
            handleResolved(
              id: resolved.attributes['id'] ?? '',
              ip: host,
              port: resolved.port,
            );
          }
        });
      }
      await discovery.start();
      _discovery = discovery;
    } catch (_) {
      // No Bonjour on this platform/build — the transport still works via
      // multicast/broadcast/unicast. Never take the mesh down over this.
      await stop();
    }
  }

  Future<void> stop() async {
    await _eventsSub?.cancel();
    _eventsSub = null;
    try {
      await _broadcast?.stop();
    } catch (_) {}
    try {
      await _discovery?.stop();
    } catch (_) {}
    _broadcast = null;
    _discovery = null;
  }
}
