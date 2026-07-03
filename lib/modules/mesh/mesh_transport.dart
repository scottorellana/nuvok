// A mesh transport moves opaque datagrams between nearby devices. The mesh
// logic (dedup, relay, crypto) lives above; transports only carry bytes, so
// WiFi-LAN today and BLE / a LoRa radio later plug in without touching the
// rest of the system.
import 'dart:typed_data';

abstract class MeshTransport {
  String get name;
  Future<void> start();
  Future<void> stop();
  Future<void> send(Uint8List datagram);
  Stream<Uint8List> get onData;
}
