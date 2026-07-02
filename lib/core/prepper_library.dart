// The portable content library: a single folder that can be copied between
// devices (Mac, Raspberry Pi, Android) without re-downloading anything.
import 'dart:convert';
import 'dart:io';

class PrepperLibrary {
  PrepperLibrary(this.root);

  final Directory root;

  static PrepperLibrary? _instance;

  static PrepperLibrary get instance {
    if (_instance != null) return _instance!;
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    _instance = PrepperLibrary(Directory('$home/PrepperPad'));
    return _instance!;
  }

  Directory get zimDir => Directory('${root.path}/zim');
  Directory get mapsDir => Directory('${root.path}/maps');
  Directory get modelsDir => Directory('${root.path}/models');
  Directory get notesDir => Directory('${root.path}/notes');
  File get settingsFile => File('${root.path}/.settings.json');

  bool get existedBefore => root.existsSync();

  Future<void> ensure() async {
    for (final d in [root, zimDir, mapsDir, modelsDir, notesDir]) {
      if (!d.existsSync()) await d.create(recursive: true);
    }
  }

  List<File> _listByExtension(Directory dir, String ext) {
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith(ext))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
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
          _settings =
              jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
        }
      } catch (_) {
        _settings = {};
      }
    }
    return _settings;
  }

  Future<void> saveSetting(String key, dynamic value) async {
    settings[key] = value;
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
