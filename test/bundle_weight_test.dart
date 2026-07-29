import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/bundled_library.dart';

/// Candado de peso: Nuvok se descarga desde nuvok.org y se comparte entre
/// teléfonos por LAN cuando no hay internet. Un instalador de gigabytes rompe
/// las dos cosas — y el APK de Android ya reventaba contra su techo de 2 GB.
///
/// El reparto es explícito: lo que viaja DENTRO del instalador ("bundled")
/// frente a lo que el usuario elige y descarga antes de la emergencia. Este
/// test impide que un archivo enorme vuelva a colarse en el instalador por
/// descuido, que es exactamente como llegó a pesar 4.8 GB.
void main() {
  late Map<String, dynamic> manifest;
  late List<Map<String, dynamic>> entries;
  late String pubspec;

  setUpAll(() {
    manifest = jsonDecode(
        File('assets/bundled_library/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    entries = (manifest['entries'] as List).cast<Map<String, dynamic>>();
    pubspec = File('pubspec.yaml').readAsStringSync();
  });

  /// Los directorios que pubspec declara bajo assets/bundled_library/.
  Set<String> declaredBundleDirs() => RegExp(
          r'^\s*-\s*(assets/bundled_library/[^\s]*)$', multiLine: true)
      .allMatches(pubspec)
      .map((m) => m.group(1)!)
      .toSet();

  bool isDeclaredAsset(String assetPath) {
    final dirs = declaredBundleDirs();
    if (dirs.contains(assetPath)) return true;
    final dir = '${assetPath.substring(0, assetPath.lastIndexOf('/'))}/';
    return dirs.contains(dir);
  }

  group('reparto entre instalador y paquetes descargables', () {
    test('cada entrada declara si viaja en el instalador', () {
      for (final e in entries) {
        expect(e['bundled'], isA<bool>(),
            reason: '"${e['label']}" no dice si va dentro del instalador; sin '
                'ese campo nadie puede auditar cuánto pesa Nuvok');
      }
    });

    test('lo que viaja dentro está declarado como asset de Flutter', () {
      for (final e in entries.where((e) => e['bundled'] == true)) {
        expect(isDeclaredAsset(e['asset'] as String), isTrue,
            reason: '"${e['label']}" dice viajar en el instalador pero pubspec '
                'no lo declara: al arrancar fallaría al no encontrar el asset');
      }
    });

    test('lo que se descarga NO se empaqueta por accidente', () {
      for (final e in entries.where((e) => e['bundled'] != true)) {
        expect(isDeclaredAsset(e['asset'] as String), isFalse,
            reason: '"${e['label']}" (${_mb(e['bytes'] as int)} MB) es un '
                'paquete descargable pero pubspec lo empaqueta igual: ese es '
                'exactamente el peso muerto que se está eliminando');
      }
    });
  });

  group('techo de peso del instalador', () {
    test('el contenido empaquetado no supera los 150 MB', () {
      final total = entries
          .where((e) => e['bundled'] == true)
          .fold<int>(0, (sum, e) => sum + (e['bytes'] as int));
      expect(total, lessThan(150 * 1024 * 1024),
          reason: 'el contenido dentro del instalador pesa ${_mb(total)} MB. '
              'Nuvok debe poder compartirse por LAN entre teléfonos sin '
              'internet: eso es imposible con un instalador de gigabytes');
    });

    test('ninguna entrada empaquetada supera el techo del APK de Android', () {
      for (final e in entries.where((e) => e['bundled'] == true)) {
        expect(e['bytes'] as int,
            lessThan(BundledLibrarySeeder.androidAssetLimitBytes),
            reason: '"${e['label']}" no cabe en un APK: la compresión de '
                'assets de AGP revienta con arrays mayores a 2 GB');
      }
    });
  });

  group('lo que se saca del instalador sigue siendo alcanzable', () {
    test('todo paquete descargable tiene checksum para verificar la descarga',
        () {
      for (final e in entries.where((e) => e['bundled'] != true)) {
        expect(e['sha256'] as String, matches(RegExp(r'^[a-f0-9]{64}$')),
            reason: '"${e['label']}" se descarga por internet: sin sha256 no '
                'hay forma de saber si llegó íntegro o manipulado');
      }
    });

    test('el asistente de IA no viaja en el instalador', () {
      final models = entries.where((e) => e['kind'] == 'models');
      expect(models, isNotEmpty, reason: 'el catálogo perdió los modelos');
      for (final e in models) {
        expect(e['bundled'], isFalse,
            reason: '"${e['label']}" pesa ${_mb(e['bytes'] as int)} MB; los '
                'modelos se eligen y descargan según el equipo del usuario');
      }
    });
  });
}

int _mb(int bytes) => (bytes / (1024 * 1024)).round();
