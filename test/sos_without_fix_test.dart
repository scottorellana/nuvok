import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/maps/location_service.dart';
import 'package:nuvok/modules/mesh/mesh_channel.dart';
import 'package:nuvok/modules/mesh/mesh_envelope.dart';
import 'package:nuvok/modules/mesh/mesh_identity.dart';
import 'package:nuvok/modules/mesh/mesh_service.dart';
import 'package:nuvok/modules/mesh/mesh_transport.dart';

/// Permiso de ubicación denegado, GPS apagado o sin fijar bajo techo: el SOS
/// sale igual, pero SIN coordenadas. Quien lo pide se queda quieto mirando un
/// cartel que dice que su posición se está difundiendo, y quien lo busca
/// recibe un aviso sin un solo dato de dónde está.
class _FakeTransport implements MeshTransport {
  final _out = <Uint8List>[];
  final _ctrl = StreamController<Uint8List>.broadcast();

  List<MeshEnvelope> get sent =>
      _out.map(MeshEnvelope.decode).whereType<MeshEnvelope>().toList();

  @override
  String get name => 'fake';
  bool get available => true;
  @override
  Stream<Uint8List> get onData => _ctrl.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(Uint8List data) async => _out.add(data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late _FakeTransport transport;
  late MeshService mesh;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('nuvok_sos_fix');
    transport = _FakeTransport();
    mesh = MeshService.forTest(
      dirPath: tmp.path,
      transports: [transport],
      identity: MeshIdentity.create('Yo'),
    );
    await mesh.start();
  });

  tearDown(() async {
    LocationService.debugCurrent = null;
    await mesh.stop();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('sin fix, el SOS sale igual pero la app NO finge que lleva posición',
      () async {
    LocationService.debugCurrent =
        () async => LocationResult(LocationStatus.permissionDenied);

    await mesh.startSos(note: 'atrapada');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await mesh.cancelSos();

    final sos = transport.sent.where((e) => e.type == MeshType.sos).toList();
    expect(sos, isNotEmpty, reason: 'el SOS debe salir aunque falte el GPS: '
        'un grito sin coordenadas sigue valiendo más que ningún grito');
    expect(mesh.sosHasPosition.value, isFalse,
        reason: 'la app tiene que SABER que su SOS va sin coordenadas para '
            'poder decírselo a quien lo lanzó');
  });

  test('con fix, el SOS lleva coordenadas y la app lo sabe', () async {
    LocationService.debugCurrent = () async => LocationResult(
        LocationStatus.ok, debugPosition(lat: 15.49, lon: -88.01));

    await mesh.startSos(note: 'atrapada');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(mesh.sosHasPosition.value, isTrue);

    final sos = transport.sent.firstWhere((e) => e.type == MeshType.sos);
    final payload =
        await openPayload(sos.payload, MeshChannel.emergency);
    expect(payload!['lat'], closeTo(15.49, 0.001));
    await mesh.cancelSos();
  });

  test('si el GPS fija más tarde, la app deja de avisar', () async {
    LocationService.debugCurrent =
        () async => LocationResult(LocationStatus.unavailable);
    await mesh.startSos();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(mesh.sosHasPosition.value, isFalse);

    // El siguiente ciclo ya tiene señal (salió del sótano).
    LocationService.debugCurrent = () async => LocationResult(
        LocationStatus.ok, debugPosition(lat: 1, lon: 2));
    await mesh.debugBroadcastSosNow();
    expect(mesh.sosHasPosition.value, isTrue,
        reason: 'el aviso debe desaparecer solo cuando el GPS fije');
    await mesh.cancelSos();
  });

  test('los rótulos del caso sin fix existen en los 7 idiomas', () {
    // Si falta una traducción, la persona que más ayuda necesita se queda con
    // el texto en un idioma que no lee — o peor, con el rótulo que miente.
    for (final key in ['sosActiveNoFix', 'sosNoFixHint']) {
      for (final lang in AppLanguage.values) {
        final s = AppStrings(lang).t(key);
        expect(s, isNotEmpty, reason: '$key falta en ${lang.code}');
        expect(s, isNot(key), reason: '$key sin traducir en ${lang.code}');
      }
    }
  });
}
