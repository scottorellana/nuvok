import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('published mobile identities remain update-compatible', () {
    final android = File('android/app/build.gradle.kts').readAsStringSync();
    final ios = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(
      android,
      contains('applicationId = "com.prepperpad.prepper_pad"'),
    );
    expect(
      RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = com\.prepperpad\.prepperPad;',
      ).allMatches(ios),
      hasLength(3),
    );
    expect(
      RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = com\.prepperpad\.prepperPad\.RunnerTests;',
      ).allMatches(ios),
      hasLength(3),
    );
  });

  test('Dart and Android use the same case-sensitive native channels', () {
    const dartContracts = <String, List<String>>{
      'lib/modules/mesh/lan_transport.dart': ['nuvok/multicast'],
      'lib/modules/mesh/ble_transport.dart': [
        'nuvok/ble_mesh',
        'nuvok/ble_mesh/events',
      ],
      'lib/modules/tools/compass.dart': [
        'nuvok/sensors',
        'nuvok/sensors/compass',
      ],
      'lib/modules/emergency/sos_alarm.dart': ['nuvok/sos_alarm'],
      'lib/core/bundled_library.dart': ['nuvok/bundled_assets'],
    };
    final android = File(
      'android/app/src/main/kotlin/org/nuvok/nuvok/MainActivity.kt',
    ).readAsStringSync();

    for (final entry in dartContracts.entries) {
      final dart = File(entry.key).readAsStringSync();
      for (final channel in entry.value) {
        expect(dart, contains("'$channel'"), reason: entry.key);
        expect(android, contains('"$channel"'), reason: channel);
      }
    }
  });
}
