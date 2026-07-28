import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pruebas del CONTRATO entre Dart y las capas nativas.
///
/// Por qué existen: la suite cubre bien la lógica en Dart, pero el puente
/// nativo (Kotlin/Swift) no lo probaba nadie — y ahí se colaron dos fallos
/// reales que solo aparecieron probando a mano en el teléfono:
///   1. applyPowerMode usaba un campo Kotlin inexistente → el APK ni
///      compilaba y se publicaba el binario anterior sin avisar.
///   2. Las radios BLE de iOS nunca arrancaban porque el método que las
///      enciende no se invocaba desde "start".
/// Estas pruebas leen el código nativo y fijan esos contratos. No sustituyen
/// una prueba en dispositivo, pero atrapan la clase de error que nos costó
/// horas, y corren en cada `flutter test`.
String _read(String path) => File(path).readAsStringSync();

void main() {
  final kotlinBle =
      _read('android/app/src/main/kotlin/org/nuvok/nuvok/BleMeshBridge.kt');
  final swiftBle = _read('ios/Runner/BleMeshBridge.swift');
  final swiftAppDelegate = _read('ios/Runner/AppDelegate.swift');
  final manifest = _read('android/app/src/main/AndroidManifest.xml');

  group('métodos que Dart invoca existen en AMBAS plataformas', () {
    // Si Dart llama a un método que el nativo no maneja, la llamada falla en
    // silencio en producción (MissingPluginException tragada).
    for (final method in ['start', 'stop', 'connect', 'disconnect', 'send',
                          'setPowerMode']) {
      test('"$method" está manejado en Kotlin y en Swift', () {
        expect(kotlinBle, contains('"$method"'),
            reason: 'Android no maneja $method del canal nuvok/ble_mesh');
        expect(swiftBle, contains('"$method"'),
            reason: 'iOS no maneja $method del canal nuvok/ble_mesh');
      });
    }
  });

  group('Kotlin: los símbolos usados existen', () {
    test('applyPowerMode solo usa campos declarados en la clase', () {
      // El fallo real: usaba 'running', que no existe (el campo es
      // 'radiosWanted'). El Kotlin no compilaba y el APK quedaba obsoleto.
      final declared = RegExp(r'private\s+(?:@Volatile\s+)?var\s+(\w+)')
          .allMatches(kotlinBle)
          .map((m) => m.group(1)!)
          .toSet();
      expect(declared, contains('radiosWanted'));
      // Dentro del bloque de energía no debe aparecer un 'running' suelto.
      final powerBlock = kotlinBle.substring(kotlinBle.indexOf('applyPowerMode'));
      expect(powerBlock.contains(RegExp(r'[^\w.]running[^\w]')), isFalse,
          reason: "'running' no existe en BleMeshBridge.kt; es 'radiosWanted'");
    });
  });

  group('iOS: las radios se encienden de verdad', () {
    test('"start" invoca el arranque de escaneo y anuncio', () {
      // El fallo real: los managers se crean al lanzar la app (para la
      // restauración de estado), así que sus callbacks de estado ya pasaron
      // con la malla apagada y NO se repiten. Si "start" no enciende las
      // radios a mano, el teléfono nunca habla por Bluetooth.
      final startBlock = swiftBle.substring(
        swiftBle.indexOf('case "start":'),
        swiftBle.indexOf('case "stop":'),
      );
      expect(startBlock, contains('startScanningIfReady'),
          reason: 'sin esto el iPhone nunca escanea por Bluetooth');
      expect(startBlock, contains('startAdvertisingIfReady'),
          reason: 'sin esto el iPhone nunca se anuncia por Bluetooth');
    });

    test('la restauración de estado se pide al ARRANCAR la app', () {
      // Apple entrega el estado restaurado durante didFinishLaunching; si lo
      // pedimos más tarde, un SOS no despierta el teléfono.
      expect(swiftAppDelegate, contains('restoreIfAuthorized'));
      expect(swiftBle, contains('CBCentralManagerOptionRestoreIdentifierKey'));
    });

    test('el SOS se detecta en nativo, sin depender del motor Dart', () {
      // Con la app en segundo plano el isolate de Dart duerme: si la
      // notificación dependiera de Dart, el SOS se perdería.
      expect(swiftBle, contains('SosSniffer.inspect'),
          reason: 'el detector nativo debe estar enganchado a la recepción');
    });
  });

  group('Android: el manifest declara lo que el código necesita', () {
    test('el servicio de segundo plano está declarado con su tipo', () {
      expect(manifest, contains('MeshForegroundService'));
      expect(manifest, contains('android:foregroundServiceType="connectedDevice"'),
          reason: 'Android 14+ rechaza el servicio sin tipo declarado');
      expect(manifest, contains('FOREGROUND_SERVICE_CONNECTED_DEVICE'));
    });

    test('el arranque tras reiniciar el teléfono está declarado', () {
      expect(manifest, contains('BootCompletedReceiver'));
      expect(manifest, contains('RECEIVE_BOOT_COMPLETED'));
      expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    });
  });

  group('el formato del sobre está replicado igual en Swift', () {
    test('el detector nativo usa el mismo magic y el mismo tipo de SOS', () {
      final sniffer = _read('ios/Runner/SosSniffer.swift');
      // 'PM01' en bytes — si el Dart cambia el magic, esto debe cambiar.
      expect(sniffer, contains('0x50, 0x4D, 0x30, 0x31'));
      // sos es el índice 2 del enum MeshType en Dart.
      final dartEnum = _read('lib/modules/mesh/mesh_envelope.dart');
      final types = RegExp(r'enum MeshType \{([^}]*)\}')
          .firstMatch(dartEnum)!
          .group(1)!
          .split(',')
          .map((e) => e.trim())
          .toList();
      expect(types.indexOf('sos'), 2,
          reason: 'si cambia el orden del enum, SosSniffer.typeSos miente '
              'y el iPhone dejaría de reconocer los SOS');
      expect(sniffer, contains('typeSos: UInt8 = 2'));
    });
  });
}
