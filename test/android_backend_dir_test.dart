import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/llama_ffi.dart';

/// En Android el motor ya no es un .so único: llama.cpp compila una librería
/// de CPU por nivel de ISA (armv8.0 sin producto escalar para los Cortex-A53
/// viejos, armv8.2 con `sdot`, armv8.6 con i8mm) y elige la mejor al arrancar.
///
/// Para elegir tiene que ENCONTRARLAS, y por su cuenta no puede: deduce la
/// carpeta leyendo /proc/self/exe, que en Android es /system/bin/app_process64
/// y no la app. Hay que decírselo.
///
/// Medido en un Android arm64 (emulador) con el binario de producción:
///   sin la llamada → "NO CARGA (no se pudo cargar el modelo)"
///   con la llamada → "loaded CPU backend from …android_armv8.2_2.so" + genera
///
/// O sea: si esta ruta se rompe, no es que la IA vaya lenta. Es que no hay IA
/// en ningún teléfono Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('nuvok/bundled_assets');

  test('el canal nativo expone dónde están las librerías', () async {
    final pedidos = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
      pedidos.add(call.method);
      if (call.method == 'nativeLibraryDir') {
        return '/data/app/~~abc/com.prepperpad.prepper_pad-1/lib/arm64';
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null));

    final dir = await debugNativeLibraryDirForTest();

    // Fuera de Android no aplica: ahí el motor va enlazado estáticamente y no
    // hay backends sueltos que buscar.
    expect(dir, isNull,
        reason: 'solo Android necesita esta ruta; pedirla en otras '
            'plataformas sería trabajo y superficie de fallo de más');
  });

  test('un canal que falla no impide cargar el modelo', () async {
    // Si el lado nativo no responde, ggml prueba sus rutas por defecto. Peor,
    // pero preferible a quedarse sin IA por una excepción no capturada.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
      throw PlatformException(code: 'BOOM');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null));

    await expectLater(debugNativeLibraryDirForTest(), completes);
  });
}
