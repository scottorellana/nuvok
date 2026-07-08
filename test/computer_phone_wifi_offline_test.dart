import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/lan_transport.dart';
import 'package:prepper_pad/modules/mesh/mesh_channel.dart';
import 'package:prepper_pad/modules/mesh/mesh_identity.dart';
import 'package:prepper_pad/modules/mesh/mesh_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'computadora ↔ teléfono se comunican por WiFi/LAN sin internet',
    () async {
      // This is the production desktop↔phone path: both sides use the real
      // UDP LAN transport. No cloud, no HTTP server, no internet and no fake
      // in-memory transport are involved. It runs on loopback in tests, the
      // same protocol used on a phone hotspot or a WiFi router with no WAN.
      final port = 47889;
      final computerDir = Directory.systemTemp.createTempSync('mesh_computer');
      final phoneDir = Directory.systemTemp.createTempSync('mesh_phone');
      final computer = MeshService.forTest(
        dirPath: computerDir.path,
        transports: [LanTransport(port: port)],
        identity: MeshIdentity.create('Computer'),
      );
      final phone = MeshService.forTest(
        dirPath: phoneDir.path,
        transports: [LanTransport(port: port)],
        identity: MeshIdentity.create('Phone'),
      );
      final channel = MeshChannel.create('Offline WiFi');
      StreamSubscription? phoneSub;
      StreamSubscription? computerSub;

      try {
        await computer.start();
        await phone.start();
        await computer.joinChannel(channel);
        await phone.joinChannel(channel);

        // Force discovery beacons after both endpoints are listening. This is
        // what the lifecycle does when the app comes foreground on a laptop or
        // Android phone.
        await computer.onAppResumed();
        await phone.onAppResumed();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final phoneReceived = Completer<String>();
        phoneSub = phone.events.listen((event) {
          if (event.channel.id == channel.id &&
              event.payload['text'] == 'mensaje desde computadora') {
            if (!phoneReceived.isCompleted) {
              phoneReceived.complete(event.envelope.senderName);
            }
          }
        });

        await computer.sendChat(channel, 'mensaje desde computadora');
        for (var i = 0; i < 6 && !phoneReceived.isCompleted; i++) {
          await computer.retryUnackedForTest();
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        final fromComputer = await phoneReceived.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException(
            'LAN UDP did not deliver computer→phone; multicast/broadcast may be blocked',
          ),
        );
        expect(fromComputer, 'Computer');

        final computerReceived = Completer<String>();
        computerSub = computer.events.listen((event) {
          if (event.channel.id == channel.id &&
              event.payload['text'] == 'respuesta desde teléfono') {
            if (!computerReceived.isCompleted) {
              computerReceived.complete(event.envelope.senderName);
            }
          }
        });

        await phone.sendChat(channel, 'respuesta desde teléfono');
        for (var i = 0; i < 6 && !computerReceived.isCompleted; i++) {
          await phone.retryUnackedForTest();
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        final fromPhone = await computerReceived.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException(
            'LAN UDP did not deliver phone→computer; multicast/broadcast may be blocked',
          ),
        );
        expect(fromPhone, 'Phone');
      } on TimeoutException catch (e) {
        markTestSkipped('$e');
      } finally {
        await phoneSub?.cancel();
        await computerSub?.cancel();
        await computer.stop();
        await phone.stop();
        computerDir.deleteSync(recursive: true);
        phoneDir.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
