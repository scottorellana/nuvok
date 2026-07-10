// Who this device is on the mesh: a random stable id plus a human name the
// user picks ("Tablet de Papá"). No accounts, no servers — the id is minted
// locally the first time and travels in every envelope.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class MeshIdentity {
  MeshIdentity({required this.id, required this.name});

  final String id; // 16 hex chars (8 random bytes)
  String name;

  static String _file(String dirPath) => '$dirPath/identity.json';

  static MeshIdentity? load(String dirPath) {
    try {
      final f = File(_file(dirPath));
      if (!f.existsSync()) return null;
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final id = j['id'] as String?;
      final name = j['name'] as String?;
      if (id == null || id.length != 16 || name == null) return null;
      return MeshIdentity(id: id, name: name);
    } catch (_) {
      return null;
    }
  }

  void save(String dirPath) {
    Directory(dirPath).createSync(recursive: true);
    File(_file(dirPath))
        .writeAsStringSync(jsonEncode({'id': id, 'name': name}));
  }

  static MeshIdentity create(String name) {
    final rnd = Random.secure();
    final id = List.generate(
        8, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return MeshIdentity(id: id, name: name);
  }

  /// A ready-to-use identity with an automatic, human-recognizable name
  /// ("Nuvok-A3F2") derived from the last 4 hex of its own id. This is what
  /// lets EVERY Nuvok join the mesh from the moment it's installed,
  /// with zero setup — nobody is invisible in an emergency because they never
  /// opened the Comunicación tab. The user can rename it later.
  static MeshIdentity auto() {
    final base = create('');
    final suffix = base.id.substring(base.id.length - 4).toUpperCase();
    return MeshIdentity(id: base.id, name: 'Nuvok-$suffix');
  }

  /// Loads the saved identity, or mints and persists an automatic one on the
  /// very first call. Idempotent: subsequent calls reuse the same identity
  /// (the mesh id must be stable across restarts).
  static MeshIdentity ensureAuto(String dirPath) {
    final existing = load(dirPath);
    if (existing != null) return existing;
    final fresh = auto()..save(dirPath);
    return fresh;
  }
}
