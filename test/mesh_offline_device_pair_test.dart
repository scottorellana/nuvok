import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/mesh_channel.dart';
import 'package:nuvok/modules/mesh/mesh_envelope.dart';
import 'package:nuvok/modules/mesh/mesh_identity.dart';
import 'package:nuvok/modules/mesh/mesh_router.dart';
import 'package:nuvok/modules/mesh/mesh_service.dart';
import 'package:nuvok/modules/mesh/mesh_transport.dart';

class LinkedMemoryTransport implements MeshTransport {
  LinkedMemoryTransport(this.name);

  @override
  final String name;

  final _incoming = StreamController<Uint8List>.broadcast();
  final peers = <LinkedMemoryTransport>[];
  bool started = false;

  void connect(LinkedMemoryTransport other) {
    if (!peers.contains(other)) peers.add(other);
    if (!other.peers.contains(this)) other.peers.add(this);
  }

  @override
  Stream<Uint8List> get onData => _incoming.stream;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Future<void> send(Uint8List datagram) async {
    for (final peer in peers) {
      if (peer.started) peer._incoming.add(Uint8List.fromList(datagram));
    }
  }
}

void main() {
  test('dos dispositivos intercambian chat 100% offline y vacían outbox',
      () async {
    final tmpA = Directory.systemTemp.createTempSync('mesh_device_a');
    final tmpB = Directory.systemTemp.createTempSync('mesh_device_b');
    final linkA = LinkedMemoryTransport('mem-a');
    final linkB = LinkedMemoryTransport('mem-b');
    linkA.connect(linkB);

    final serviceA = MeshService.forTest(
      dirPath: tmpA.path,
      transports: [linkA],
      identity: MeshIdentity.create('Alice'),
    );
    final serviceB = MeshService.forTest(
      dirPath: tmpB.path,
      transports: [linkB],
      identity: MeshIdentity.create('Bob'),
    );
    final channel = MeshChannel.create('Grupo offline');

    try {
      await serviceA.start();
      await serviceB.start();
      await serviceA.joinChannel(channel);
      await serviceB.joinChannel(channel);

      // Force fresh beacons after both transports are listening. No internet,
      // no router: this is only the in-memory device-to-device link.
      await serviceA.onAppResumed();
      await serviceB.onAppResumed();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final receivedByB = Completer<MeshEvent>();
      final subB = serviceB.events.listen((event) {
        if (event.envelope.type == MeshType.chat &&
            event.payload['text'] == 'mensaje offline') {
          if (!receivedByB.isCompleted) receivedByB.complete(event);
        }
      });

      await serviceA.sendChat(channel, 'mensaje offline');
      final event =
          await receivedByB.future.timeout(const Duration(seconds: 2));
      expect(event.envelope.senderName, 'Alice');
      expect(event.channel.id, channel.id);

      // ACK/outbox housekeeping should leave A with no queued datagrams.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(serviceA.queuedCount.value, 0);
      expect(serviceB.queuedCount.value, 0);
      await subB.cancel();
    } finally {
      await serviceA.stop();
      await serviceB.stop();
      tmpA.deleteSync(recursive: true);
      tmpB.deleteSync(recursive: true);
    }
  });
}
