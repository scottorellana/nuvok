// LoRa transport — the long-range radio path for Prepper Mesh.
//
// STATUS: hardware pending. The physical Prepper LoRa radio (sold as a $150
// add-on) does not ship yet, so this adapter is the integration point, not a
// finished driver. It implements the same [MeshTransport] interface as the
// WiFi transport, so when the radio exists the rest of the mesh (channels,
// encryption, dedup, relay, SOS, positions) works over LoRa with zero changes
// above this file.
//
// How the radio connects, per platform (all offline — the device is wired or
// paired directly to the machine, no internet):
//   • macOS / Windows / Linux: USB serial (CDC-ACM). The radio appears as a
//     serial port (/dev/tty.usb… , COMx). We speak a small framed protocol:
//     our binary MeshEnvelope is chunked into LoRa payloads (max ~230 bytes)
//     and reassembled on the other side. A serial package (e.g. a Dart FFI
//     wrapper over libserialport) provides read/write.
//   • Android: USB-OTG serial (usb-serial-for-android via a platform channel)
//     when the radio is plugged into the tablet, or BLE when the radio
//     exposes a Nordic UART service — the same transport, two link layers.
//
// Wire compatibility: the radio runs Meshtastic-class firmware (Apache 2.0),
// so Prepper Pad interoperates with the wider LoRa mesh community. The adapter
// maps our MeshEnvelope onto the radio's packet format 1:1 because the mesh
// semantics were designed to match (hop limit, channel id, dedup).
//
// Until a device is detected, [available] is false and the app simply doesn't
// offer LoRa — WiFi mesh keeps working. This file is intentionally NOT wired
// into MeshService's default transports yet: shipping an untested serial
// driver would risk the verified WiFi path. When the hardware lands, detect a
// device here and pass a started LoraTransport into MeshService alongside the
// LAN transport.
import 'dart:async';
import 'dart:typed_data';

import 'mesh_transport.dart';

/// The link layer a LoRa radio is reached through on a given device.
enum LoraLink { usbSerial, bleUart }

class LoraTransport implements MeshTransport {
  LoraTransport({this.link = LoraLink.usbSerial, this.portName});

  final LoraLink link;
  final String? portName; // serial port path / BLE device id, when known

  final _data = StreamController<Uint8List>.broadcast();
  bool _open = false;

  /// True once a physical radio is connected and opened. Always false today
  /// because no driver is bound — the hardware is a future product.
  bool get available => _open;

  @override
  String get name => 'lora';

  @override
  Stream<Uint8List> get onData => _data.stream;

  /// Detects and opens a connected radio. Returns false when none is present
  /// (the normal case until the hardware ships), so callers fall back to WiFi.
  Future<bool> tryOpen() async {
    // TODO(hardware): enumerate serial ports / BLE peripherals, handshake
    // with the radio, and set _open = true on success. No-op until the
    // physical device and its driver package are available.
    return false;
  }

  @override
  Future<void> start() async {
    _open = await tryOpen();
  }

  @override
  Future<void> stop() async {
    _open = false;
  }

  @override
  Future<void> send(Uint8List datagram) async {
    if (!_open) return; // no radio attached; WiFi transport carries traffic
    // TODO(hardware): fragment [datagram] into LoRa-sized frames and write
    // them to the serial/BLE link; reassembled frames arrive on [onData].
  }
}
