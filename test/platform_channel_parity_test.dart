import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Los nombres de canal de Flutter son case-sensitive y viven duplicados en
/// Dart, Kotlin y Swift. Un typo en UNO deja esa plataforma muda en silencio
/// (MissingPluginException tragada) — exactamente lo que dejó al iPhone
/// invisible por BLE tras el rename ("Nuvok/ble_mesh" vs "nuvok/ble_mesh").
/// Este test extrae los canales reales de cada plataforma y exige paridad.
void main() {
  Set<String> channelsIn(String root, Pattern filePattern, RegExp channelRe) {
    final out = <String>{};
    for (final f in Directory(root).listSync(recursive: true)) {
      if (f is! File || !f.path.contains(filePattern)) continue;
      final src = f.readAsStringSync();
      for (final m in channelRe.allMatches(src)) {
        out.add(m.group(1)!);
      }
    }
    return out;
  }

  test('todo canal nuvok/* de Dart existe EXACTO en Kotlin y Swift', () {
    final dart = channelsIn(
      'lib',
      RegExp(r'\.dart$'),
      RegExp("(?:MethodChannel|EventChannel)\\('([^']+)'\\)"),
    );
    final kotlin = channelsIn(
      'android/app/src/main/kotlin',
      RegExp(r'\.kt$'),
      RegExp('(?:MethodChannel|EventChannel)\\([^,]+,\\s*"([^"]+)"'),
    );
    final swiftIos = channelsIn(
      'ios/Runner',
      RegExp(r'\.swift$'),
      RegExp('name:\\s*"([^"]+)"'),
    );
    final swiftMac = channelsIn(
      'macos/Runner',
      RegExp(r'\.swift$'),
      RegExp('name:\\s*"([^"]+)"'),
    );

    expect(dart, isNotEmpty);

    // Canales implementados por CADA plataforma (los específicos de una sola
    // plataforma se declaran aquí y no se exigen en las demás).
    const androidOnly = {'nuvok/multicast', 'nuvok/bundled_assets'};
    const appleImplements = {
      'nuvok/ble_mesh',
      'nuvok/ble_mesh/events',
      'nuvok/sensors',
      'nuvok/sensors/compass',
    };

    for (final ch in dart) {
      if (!androidOnly.contains(ch)) {
        // Nada que Dart use puede faltar (o variar en mayúsculas) en Apple si
        // Apple lo implementa.
        if (appleImplements.contains(ch)) {
          expect(swiftIos, contains(ch),
              reason: 'iOS no registra "$ch" — ¿typo de mayúsculas? '
                  'Registrados: $swiftIos');
          expect(swiftMac, contains(ch),
              reason: 'macOS no registra "$ch". Registrados: $swiftMac');
        }
      }
      expect(kotlin, contains(ch),
          reason: 'Android no registra "$ch". Registrados: $kotlin');
    }

    // Y a la inversa: nada registrado en nativo con casing distinto.
    for (final ch in {...swiftIos, ...swiftMac, ...kotlin}) {
      if (ch.toLowerCase().startsWith('nuvok/')) {
        expect(dart, contains(ch),
            reason: 'El canal nativo "$ch" no coincide con ningún canal Dart '
                '(¿mayúsculas?). Dart usa: $dart');
      }
    }
  });
}
