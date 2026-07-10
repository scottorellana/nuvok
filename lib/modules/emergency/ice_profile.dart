// Ficha médica ICE (In Case of Emergency): inconsciente no puedes decir
// "soy alérgico a la penicilina". La ficha vive en disco, se muestra GRANDE
// a un rescatista, viaja por el mesh y se exporta como QR imprimible.
import 'dart:convert';
import 'dart:io';

class IceProfile {
  const IceProfile({
    required this.name,
    required this.bloodType,
    required this.allergies,
    required this.medications,
    required this.conditions,
    required this.contact1,
    required this.contact2,
  });

  final String name;
  final String bloodType;
  final String allergies;
  final String medications;
  final String conditions;
  final String contact1;
  final String contact2;

  /// Texto plano para el rescatista (pantalla grande, QR y mesh). Los campos
  /// vacíos se omiten: en emergencia el ruido cuesta segundos.
  String rescueText() {
    final b = StringBuffer('🆘 ICE — $name\n');
    if (bloodType.isNotEmpty) b.writeln('Sangre: $bloodType');
    if (allergies.isNotEmpty) b.writeln('Alergias: $allergies');
    if (medications.isNotEmpty) b.writeln('Medicamentos: $medications');
    if (conditions.isNotEmpty) b.writeln('Condiciones: $conditions');
    if (contact1.isNotEmpty) b.writeln('Contacto: $contact1');
    if (contact2.isNotEmpty) b.writeln('Contacto 2: $contact2');
    return b.toString().trimRight();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'bloodType': bloodType,
        'allergies': allergies,
        'medications': medications,
        'conditions': conditions,
        'contact1': contact1,
        'contact2': contact2,
      };

  static IceProfile fromJson(Map<String, dynamic> j) => IceProfile(
        name: j['name'] as String? ?? '',
        bloodType: j['bloodType'] as String? ?? '',
        allergies: j['allergies'] as String? ?? '',
        medications: j['medications'] as String? ?? '',
        conditions: j['conditions'] as String? ?? '',
        contact1: j['contact1'] as String? ?? '',
        contact2: j['contact2'] as String? ?? '',
      );
}

class IceStore {
  IceStore(this.dirPath) {
    _load();
  }

  final String dirPath;
  IceProfile? profile;

  File get _file => File('$dirPath/ice_profile.json');

  void _load() {
    try {
      if (!_file.existsSync()) return;
      final raw = jsonDecode(_file.readAsStringSync());
      if (raw is Map<String, dynamic>) profile = IceProfile.fromJson(raw);
    } catch (_) {
      profile = null;
    }
  }

  void save(IceProfile p) {
    profile = p;
    try {
      Directory(dirPath).createSync(recursive: true);
      _file.writeAsStringSync(jsonEncode(p.toJson()));
    } catch (_) {}
  }
}
