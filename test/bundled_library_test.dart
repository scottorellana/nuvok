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
    for (final entry in manifest.entries) {
      // models_xl/ NO son assets de Flutter: van como recurso nativo del
      // bundle en iOS/macOS (Android no puede empaquetar >2GB en el APK y
      // los assets de pubspec son globales a todas las plataformas).
      if (entry.assetPath.contains('/models_xl/')) continue;
      expect(registered, contains(entry.assetPath), reason: entry.assetPath);
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

  group('platform seeding scope', () {
    BundledLibraryEntry entry(String kind, String name) => BundledLibraryEntry(
          kind: kind,
          label: name,
          assetPath: 'assets/bundled_library/$kind/$name',
          targetRelativePath: '$kind/$name',
          bytes: 1,
          sha256: '0' * 64,
        );

    final all = [
      entry('maps', 'honduras.pmtiles'),
      entry('zim', 'wikipedia.zim'),
      entry('models', 'qwen.gguf'),
    ];

    test('iOS seeds only the AI model (not the multi-GB maps/zim)', () {
      final selected = BundledLibrarySeeder.entriesToSeed(all, isIOS: true);
      expect(selected.map((e) => e.kind), ['models'],
          reason: 'iOS: solo el modelo IA, para no duplicar >1GB de mapas/zim');
    });

    test('non-iOS platforms seed the whole bundle', () {
      final selected = BundledLibrarySeeder.entriesToSeed(all, isIOS: false);
      expect(selected, equals(all),
          reason: 'macOS: instalación única completa, sin cambios');
    });

    test('Android salta los assets que su APK no puede llevar (>2GB)', () {
      final big = BundledLibraryEntry(
        kind: 'models',
        label: 'Gemma 4 E2B',
        assetPath: 'assets/bundled_library/models/gemma.gguf',
        targetRelativePath: 'models/gemma.gguf',
        bytes: 3427877696, // excluido del APK por build.gradle
        sha256: '0' * 64,
      );
      final selected = BundledLibrarySeeder.entriesToSeed([...all, big],
          isIOS: false, isAndroid: true);
      expect(selected, equals(all),
          reason: 'el asset >2GB no está en el APK; sembrarlo fallaría');
    });
  });
}
