import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/bundled_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Hashea ~1.3GB de assets reales: bajo la carga de la suite completa
  // excede el timeout default de 30s y se vuelve flaky. Tiempo holgado.
  test('bundled library manifest is complete, safe and checksum verified',
      timeout: const Timeout(Duration(minutes: 3)), () {
    final manifestFile = File('assets/bundled_library/manifest.json');
    expect(manifestFile.existsSync(), isTrue);

    final manifest = BundledLibraryManifest.fromJson(
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
    );
    expect(manifest.entries, isNotEmpty);

    final byKind = <String, int>{};
    var totalBytes = 0;
    for (final entry in manifest.entries) {
      byKind.update(entry.kind, (v) => v + 1, ifAbsent: () => 1);
      totalBytes += entry.bytes;

      expect(entry.assetPath.startsWith('assets/bundled_library/'), isTrue);
      expect(entry.targetRelativePath.startsWith('/'), isFalse);
      expect(entry.targetRelativePath.split('/'), isNot(contains('..')));
      expect(entry.bytes, greaterThan(0));
      expect(entry.sha256, hasLength(64));

      final file = File(entry.assetPath);
      expect(file.existsSync(), isTrue, reason: entry.assetPath);
      expect(file.lengthSync(), entry.bytes, reason: entry.assetPath);
      expect(sha256.convert(file.readAsBytesSync()).toString(), entry.sha256,
          reason: entry.assetPath);
    }

    expect(byKind['maps'], greaterThanOrEqualTo(1),
        reason: 'la instalación única debe traer mapas offline');
    expect(byKind['zim'], greaterThanOrEqualTo(1),
        reason: 'la instalación única debe traer biblioteca offline');
    expect(byKind['models'], greaterThanOrEqualTo(1),
        reason: 'la instalación única debe traer modelo IA offline');
    expect(totalBytes, greaterThan(1024 * 1024 * 1024),
        reason: 'este build debe ser autosuficiente, no un shell vacío');
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
