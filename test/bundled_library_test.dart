import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/bundled_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // NOTA: este test era de la era del instalador gordo — hasheaba 4.5 GB de
  // modelos/mapas desde disco (archivos gitignorados que solo existen en la
  // máquina de release) y exigía "build autosuficiente >1GB". Con el
  // instalador ligero eso es exactamente al revés: SOLO lo marcado 'bundled'
  // viaja dentro y debe existir en cualquier clon; el resto son descargas y
  // aquí solo se valida su metadata. En CI (Linux, clon limpio) la versión
  // vieja moría: los archivos grandes no existen ahí.
  test('bundled library manifest is complete, safe and checksum verified', () {
    final manifestFile = File('assets/bundled_library/manifest.json');
    expect(manifestFile.existsSync(), isTrue);

    final manifest = BundledLibraryManifest.fromJson(
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
    );
    expect(manifest.entries, isNotEmpty);

    for (final entry in manifest.entries) {
      expect(entry.assetPath.startsWith('assets/bundled_library/'), isTrue);
      expect(entry.targetRelativePath.startsWith('/'), isFalse);
      expect(entry.targetRelativePath.split('/'), isNot(contains('..')));
      expect(entry.bytes, greaterThan(0));
      expect(entry.sha256, hasLength(64),
          reason: '${entry.label}: sin checksum no hay verificación posible, '
              'ni al sembrar ni al descargar');
    }

    // Lo empaquetado existe en CUALQUIER clon y su checksum es real.
    final bundled = manifest.entries.where((e) => e.bundled).toList();
    expect(bundled, isNotEmpty,
        reason: 'algo debe viajar dentro (la Biblioteca no puede abrir vacía)');
    for (final entry in bundled) {
      final file = File(entry.assetPath);
      expect(file.existsSync(), isTrue, reason: entry.assetPath);
      expect(file.lengthSync(), entry.bytes, reason: entry.assetPath);
      expect(sha256.convert(file.readAsBytesSync()).toString(), entry.sha256,
          reason: entry.assetPath);
    }

    // El catálogo descargable cubre lo que la app promete en el primer
    // arranque: IA, biblioteca y mapas.
    final kinds = manifest.entries.map((e) => e.kind).toSet();
    expect(kinds, containsAll(<String>{'models', 'zim', 'maps'}));
  });

  test('bundled library assets are registered in Flutter AssetManifest',
      () async {
    final manifestFile = File('assets/bundled_library/manifest.json');
    final manifest = BundledLibraryManifest.fromJson(
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
    );
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final registered = assetManifest.listAssets().toSet();

    expect(registered, contains(BundledLibraryManifest.assetPath));
    // Solo lo marcado como empaquetado debe existir como asset. Lo demás son
    // paquetes que se descargan: si aparecieran aquí, estarían inflando el
    // instalador sin que nadie lo note.
    for (final entry in manifest.entries.where((e) => e.bundled)) {
      expect(registered, contains(entry.assetPath), reason: entry.assetPath);
    }
    for (final entry in manifest.entries.where((e) => !e.bundled)) {
      expect(registered, isNot(contains(entry.assetPath)),
          reason: '${entry.label} se descarga; no debe viajar en el paquete');
    }
  });

  test('bundled library resolves entries into the portable Nuvok library',
      () {
    final entry = BundledLibraryEntry(
      kind: 'maps',
      label: 'Mapa',
      assetPath: 'assets/bundled_library/maps/honduras.pmtiles',
      targetRelativePath: 'maps/honduras.pmtiles',
      bytes: 1,
      sha256: '0' * 64,
    );

    final root = Directory('/tmp/Nuvok-pad-test-root');
    final resolved = entry.resolveTarget(root);
    expect(resolved.path, '${root.path}/maps/honduras.pmtiles');
  });

  test('bundled library rejects unsafe target paths', () {
    expect(
      () => BundledLibraryEntry(
        kind: 'zim',
        label: 'Bad',
        assetPath: 'assets/bundled_library/zim/bad.zim',
        targetRelativePath: '../bad.zim',
        bytes: 1,
        sha256: '0' * 64,
      ),
      throwsArgumentError,
    );
  });

  group('qué se siembra al instalar', () {
    BundledLibraryEntry entry(String kind, String name,
            {required bool bundled, int bytes = 1}) =>
        BundledLibraryEntry(
          kind: kind,
          label: name,
          assetPath: 'assets/bundled_library/$kind/$name',
          targetRelativePath: '$kind/$name',
          bytes: bytes,
          sha256: '0' * 64,
          bundled: bundled,
        );

    final mini = entry('zim', 'wikipedia_mini.zim', bundled: true);
    final mapa = entry('maps', 'honduras.pmtiles', bundled: false);
    final modelo = entry('models', 'gemma.gguf', bundled: false);
    final all = [mini, mapa, modelo];

    test('solo se siembra lo que viaja dentro del instalador', () {
      for (final ios in [true, false]) {
        final selected =
            BundledLibrarySeeder.entriesToSeed(all, isIOS: ios);
        expect(selected, equals([mini]),
            reason: 'iOS=$ios: sembrar un paquete no empaquetado fallaría, '
                'porque el asset no existe dentro de la app');
      }
    });

    test('una entrada sin el campo "bundled" no infla el instalador', () {
      // Por defecto NO se empaqueta: olvidar el campo debe fallar del lado
      // seguro (la app ofrece descargarlo), no meter gigabytes en silencio.
      final sinCampo = BundledLibraryEntry.fromJson({
        'kind': 'models',
        'label': 'Modelo nuevo',
        'asset': 'assets/bundled_library/models/nuevo.gguf',
        'target': 'models/nuevo.gguf',
        'bytes': 2000000000,
        'sha256': '0' * 64,
      });
      expect(sinCampo.bundled, isFalse);
      expect(BundledLibrarySeeder.entriesToSeed([sinCampo], isIOS: false),
          isEmpty);
    });

    test('Android descarta lo que su APK no puede llevar (>2GB)', () {
      // Red de seguridad: si algo enorme se marcara como empaquetado, el APK
      // ni siquiera lo contendría y sembrarlo reventaría.
      final gigante = entry('models', 'gigante.gguf',
          bundled: true, bytes: 3427877696);
      final selected = BundledLibrarySeeder.entriesToSeed(
          [...all, gigante],
          isIOS: false,
          isAndroid: true);
      expect(selected, equals([mini]));
    });
  });
}
