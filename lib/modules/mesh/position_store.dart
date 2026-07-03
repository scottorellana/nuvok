// Live positions and SOS alerts heard on the mesh, shared with the Maps
// module: teammates appear as named markers, active SOS as red pins.
import 'package:flutter/foundation.dart';

class PeerPosition {
  PeerPosition({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.time,
    this.accuracy,
    this.isSos = false,
    this.sosNote,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final DateTime time;
  final double? accuracy;
  final bool isSos;
  final String? sosNote;
}

class PositionStore {
  PositionStore._();
  static final PositionStore instance = PositionStore._();

  /// senderId → last known position. SOS entries stay until cancelled.
  final ValueNotifier<Map<String, PeerPosition>> peers = ValueNotifier({});

  void update(PeerPosition p) {
    final next = Map<String, PeerPosition>.of(peers.value);
    // An SOS position must not be silently downgraded by a later plain
    // position broadcast from the same device.
    final prev = next[p.id];
    if (prev != null && prev.isSos && !p.isSos) {
      next[p.id] = PeerPosition(
        id: p.id,
        name: p.name,
        lat: p.lat,
        lon: p.lon,
        time: p.time,
        accuracy: p.accuracy,
        isSos: true,
        sosNote: prev.sosNote,
      );
    } else {
      next[p.id] = p;
    }
    peers.value = next;
  }

  void clearSos(String id) {
    final next = Map<String, PeerPosition>.of(peers.value);
    final prev = next[id];
    if (prev == null) return;
    next[id] = PeerPosition(
      id: prev.id,
      name: prev.name,
      lat: prev.lat,
      lon: prev.lon,
      time: prev.time,
      accuracy: prev.accuracy,
      isSos: false,
    );
    peers.value = next;
  }

  /// Positions fresh enough to show on the map.
  List<PeerPosition> recent({Duration maxAge = const Duration(minutes: 15)}) {
    final now = DateTime.now();
    return [
      for (final p in peers.value.values)
        if (p.isSos || now.difference(p.time) < maxAge) p,
    ];
  }
}
