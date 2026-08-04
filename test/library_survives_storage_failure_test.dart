import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/nuvok_library.dart';

/// Nuvok vive en el almacenamiento externo de la app. Ese almacenamiento no
/// siempre está listo cuando la app arranca:
///
/// - Tras REINICIAR y antes del primer desbloqueo, Android mantiene cifrado el
///   almacenamiento por credencial. Y en un apagón el teléfono se reinicia
///   solo, por batería: justo entonces alguien abre Nuvok.
/// - Con la tarjeta SD extraída o el volumen desmontado.
/// - Con el sistema de archivos en solo lectura por un error de disco.
///
/// Medido en un Android arm64 (emulador, APK release):
///   Unhandled Exception: FileSystemException: Exists failed, path =
///   '…/files/Nuvok/zim' (OS Error: Permission denied, errno = 13)
///     #1 NuvokLibrary.ensure   #2 main
///
/// Una excepción sin capturar ahí mata main() ANTES de runApp: pantalla negra.
/// Una app de emergencias tiene que arrancar igual — sus guías, su brújula, su
/// linterna y su SOS no dependen de que exista esa carpeta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('nuvok_lib');
  });

  tearDown(() {
    try {
      Process.runSync('chmod', ['-R', 'u+w', tmp.path]);
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('con almacenamiento sano, crea toda la biblioteca', () async {
    final lib = NuvokLibrary(Directory('${tmp.path}/Nuvok'));
    await lib.ensure();

    expect(lib.root.existsSync(), isTrue);
    expect(lib.zimDir.existsSync(), isTrue);
    expect(lib.modelsDir.existsSync(), isTrue);
    expect(lib.storageUsable, isTrue);
  });

  test('un almacenamiento de SOLO LECTURA no tumba el arranque', () async {
    final readOnly = Directory('${tmp.path}/ro')..createSync();
    Process.runSync('chmod', ['555', readOnly.path]);

    final lib = NuvokLibrary(Directory('${readOnly.path}/Nuvok'));

    // Lo que importa: NO lanza. Antes esto subía a main() y dejaba al usuario
    // mirando una pantalla negra.
    await expectLater(lib.ensure(), completes);
    expect(lib.storageUsable, isFalse,
        reason: 'la app tiene que SABER que no puede guardar, para decírselo '
            'al usuario en vez de fallar en silencio al descargar');
  });

  test('listar en una biblioteca inaccesible devuelve vacío, no explota',
      () async {
    final lib = NuvokLibrary(Directory('/proc/nuvok_no_existe'));
    await lib.ensure();

    expect(lib.listModels(), isEmpty);
    expect(lib.listZims(), isEmpty);
    expect(lib.listMaps(), isEmpty);
  });

  test('un fallo parcial no impide crear el resto', () async {
    // La carpeta raíz existe pero una subcarpeta ya está ocupada por un
    // ARCHIVO con ese nombre: crearla falla, las demás no tienen por qué.
    final root = Directory('${tmp.path}/Nuvok')..createSync(recursive: true);
    File('${root.path}/zim').writeAsStringSync('no soy una carpeta');

    final lib = NuvokLibrary(root);
    await expectLater(lib.ensure(), completes);
    expect(lib.modelsDir.existsSync(), isTrue,
        reason: 'que falle zim no puede dejar sin models a los especialistas');
  });
}
