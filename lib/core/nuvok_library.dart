// The portable content library: a single folder that can be copied between
// devices (Mac, Raspberry Pi, Android) without re-downloading anything.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class NuvokLibrary {
  NuvokLibrary(this.root);

  final Directory root;

  static NuvokLibrary? _instance;

  @visibleForTesting
  static void setInstanceForTest(Directory root) {
    _instance = NuvokLibrary(root);
  }

  /// Selects the Nuvok library root while preserving a published PrepperPad
  /// library. Rename is atomic on the normal same-volume layout; if the
  /// filesystem rejects it, keep using the legacy root instead of exposing an
  /// empty library or attempting a partial multi-gigabyte copy.
  @visibleForTesting
  static Future<Directory> migrateLegacyRoot({
    required Directory current,
    required Directory legacy,
  }) async {
    if (current.existsSync() || !legacy.existsSync()) return current;
    try {
      await legacy.rename(current.path);
      return current;
    } on FileSystemException {
      return legacy;
    }
  }

  /// Must be called once before [instance] (see main). On desktop the
  /// library lives in the user's home folder so it's easy to find and copy
  /// by USB; on Android it lives in the app's external files dir, visible
  /// when the device is plugged into a computer.
  static Future<void> init() async {
    if (_instance != null) return;
    late final Directory base;
    if (Platform.isAndroid) {
      base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      // iOS has no usable $HOME env var (resolving it gave '//Nuvok' at
      // the read-only filesystem root and killed startup). The sandboxed
      // Documents dir is the right home; it's also visible in the Files app
      // and finder-shareable, matching the "portable library" idea.
      base = await getApplicationDocumentsDirectory();
    } else {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Directory.current.path;
      base = Directory(home);
    }
    final root = await migrateLegacyRoot(
      current: Directory('${base.path}/Nuvok'),
      legacy: Directory('${base.path}/PrepperPad'),
    );
    _instance = NuvokLibrary(root);
  }

  static NuvokLibrary get instance {
    if (_instance == null) {
      throw StateError('NuvokLibrary.init() no fue llamado');
    }
    return _instance!;
  }

  Directory get zimDir => Directory('${root.path}/zim');
  Directory get mapsDir => Directory('${root.path}/maps');
  Directory get modelsDir => Directory('${root.path}/models');
  Directory get notesDir => Directory('${root.path}/notes');
  File get settingsFile => File('${root.path}/.settings.json');

  bool get existedBefore {
    try {
      return root.existsSync();
    } catch (_) {
      return false;
    }
  }

  /// ¿Se pudo preparar la biblioteca en disco?
  ///
  /// false = la app funciona igual (guías empaquetadas, brújula, linterna,
  /// malla, SOS), pero no podrá guardar descargas ni notas. Quien lo consulte
  /// puede decírselo al usuario ANTES de que empiece a bajar dos gigas.
  bool get storageUsable => _storageUsable;
  bool _storageUsable = false;

  /// Prepara las carpetas de la biblioteca. NUNCA lanza.
  ///
  /// El almacenamiento externo no siempre está listo al arrancar: tras un
  /// reinicio y antes del primer desbloqueo Android lo mantiene cifrado — y en
  /// un apagón el teléfono se reinicia solo, por batería, que es justo cuando
  /// alguien abre Nuvok. También pasa con la SD fuera o el volumen en solo
  /// lectura.
  ///
  /// Esto lanzaba y la excepción subía hasta main(), ANTES de runApp: pantalla
  /// negra. Medido en un Android real con el APK release:
  ///   FileSystemException: Exists failed … (OS Error: Permission denied)
  ///     #1 NuvokLibrary.ensure   #2 main
  ///
  /// Una app de emergencias arranca aunque no pueda escribir. Cada carpeta se
  /// intenta por separado: que falle una no puede dejar sin las demás.
  Future<void> ensure() async {
    var ok = false;
    for (final d in [root, zimDir, mapsDir, modelsDir, notesDir]) {
      try {
        if (!d.existsSync()) await d.create(recursive: true);
        if (identical(d, root) || d.path == root.path) ok = true;
      } catch (_) {
        // Sin sitio donde escribir. Se sigue: las guías van dentro de la app.
      }
    }
    try {
      _storageUsable = root.existsSync();
    } catch (_) {
      _storageUsable = false;
    }
    if (ok && !_storageUsable) _storageUsable = false;
  }

  List<File> _listByExtension(Directory dir, String ext) {
    try {
      if (!dir.existsSync()) return [];
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith(ext))
          .toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      return files;
    } catch (_) {
      // Volumen desmontado o sin permiso: no hay contenido que ofrecer, pero
      // eso no puede tumbar la pantalla que lo pregunta.
      return const [];
    }
  }

  List<File> listZims() => _listByExtension(zimDir, '.zim');
  List<File> listMaps() => _listByExtension(mapsDir, '.pmtiles');
  List<File> listModels() => _listByExtension(modelsDir, '.gguf');
  List<File> listNotes() => _listByExtension(notesDir, '.md');

  // -- Settings (portable JSON stored inside the library) --------------------

  Map<String, dynamic> _settings = {};
  bool _settingsLoaded = false;

  Map<String, dynamic> get settings {
    if (!_settingsLoaded) {
      _settingsLoaded = true;
      try {
        if (settingsFile.existsSync()) {
          final content = settingsFile.readAsStringSync();
          if (content.isNotEmpty) {
            _settings = jsonDecode(content) as Map<String, dynamic>;
          }
        }
      } on FormatException catch (_) {
        // JSON corrupto: resetear a defaults
        _settings = {};
      } on FileSystemException {
        // Sin acceso al archivo: defaults silenciosos
        _settings = {};
      } catch (_) {
        // Cualquier otro error: defaults seguros
        _settings = {};
      }
    }
    return _settings;
  }

  Future<void> saveSetting(String key, dynamic value) async {
    settings[key] = value;
    // El directorio puede no existir todavía (máquina fresca, o ajustes
    // guardados antes de ensure()): sin esto, writeAsString revienta con
    // PathNotFoundException en el primer arranque de un entorno limpio.
    await settingsFile.parent.create(recursive: true);
    await settingsFile.writeAsString(jsonEncode(_settings));
  }
}

String humanSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var u = 0;
  while (size >= 1024 && u < units.length - 1) {
    size /= 1024;
    u++;
  }
  return '${size.toStringAsFixed(size >= 100 || u == 0 ? 0 : 1)} ${units[u]}';
}
