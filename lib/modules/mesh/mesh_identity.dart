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
}
