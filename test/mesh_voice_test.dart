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
import 'package:nuvok/modules/mesh/voice_note.dart';

class _CaptureTransport implements MeshTransport {
  final sent = <Uint8List>[];
  final _incoming = StreamController<Uint8List>.broadcast();
  @override
  String get name => 'fake';
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List datagram) async => sent.add(datagram);
  @override
  Stream<Uint8List> get onData => _incoming.stream;
  void inject(Uint8List d) => _incoming.add(d);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sendVoice transmite el clip y queda en el historial con eco local',
      () async {
    final dir = Directory.systemTemp.createTempSync('meshvoice').path;
    final t = _CaptureTransport();
    final svc = MeshService.forTest(
      dirPath: dir,
      transports: [t],
      identity: MeshIdentity.create('Emisor'),
    );
    await svc.start();
    final canal = svc.channels.isEmpty
        ? MeshChannel.emergency
        : svc.channels.first;

    final audio = Uint8List.fromList(List.generate(2000, (i) => i & 0xff));
    final events = <MeshEvent>[];
    final sub = svc.events.listen(events.add);

    final ok = await svc.sendVoice(canal, audio, 3500);
    expect(ok, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    // Salió al aire por el transporte.
    final voiceOnWire = t.sent
        .map(MeshEnvelope.decode)
        .whereType<MeshEnvelope>()
        .where((e) => e.type == MeshType.voice);
    expect(voiceOnWire, isNotEmpty);

    // Eco local para la UI.
    expect(events.any((e) => e.envelope.type == MeshType.voice), isTrue);

    // Historial persistido con el tipo correcto.
    final history = svc.store.loadMessages(canal.id);
    expect(history.any((m) => m['_type'] == 'voice'), isTrue);

    await sub.cancel();
    await svc.stop();
  });

  test('voiceFile cachea los bytes a disco una sola vez', () async {
    final dir = Directory.systemTemp.createTempSync('meshvoice2').path;
    final svc = MeshService.forTest(
      dirPath: dir,
      transports: [_CaptureTransport()],
      identity: MeshIdentity.create('Receptor'),
    );
    final note =
        VoiceNote(audio: Uint8List.fromList([1, 2, 3, 4]), durationMs: 900);
    final f1 = await svc.voiceFile(1234, note);
    expect(f1.existsSync(), isTrue);
    expect(f1.readAsBytesSync(), [1, 2, 3, 4]);
    // Segunda llamada: mismo archivo, sin reescribir.
    final mtime = f1.statSync().modified;
    final f2 = await svc.voiceFile(1234, note);
    expect(f2.path, f1.path);
    expect(f2.statSync().modified, mtime);
  });
}
