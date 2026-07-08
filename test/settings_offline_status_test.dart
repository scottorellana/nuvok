import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/core/bundled_library.dart';
import 'package:prepper_pad/modules/settings/settings_page.dart';

void main() {
  test('settings offline status summarizes the bundled starter pack', () {
    final manifestFile = File('assets/bundled_library/manifest.json');
    final manifest = BundledLibraryManifest.fromJson(
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
    );

    final summary = OfflineReadinessSummary.fromManifest(manifest);

    expect(summary.hasCoreStarterPack, isTrue);
    expect(summary.maps, greaterThanOrEqualTo(2));
    expect(summary.zims, greaterThanOrEqualTo(1));
    expect(summary.models, greaterThanOrEqualTo(1));
    expect(summary.bundleLabel, contains('mapas'));
    expect(summary.bundleLabel, contains('ZIM'));
    expect(summary.bundleLabel, contains('IA'));
    expect(summary.sizeLabel, isNotEmpty);
  });

  test('settings page no longer hardcodes the app version label', () {
    final source =
        File('lib/modules/settings/settings_page.dart').readAsStringSync();

    expect(source, contains('PackageInfo.fromPlatform'));
    expect(source, isNot(contains('Prepper Pad v0.2.8')));
  });
}
