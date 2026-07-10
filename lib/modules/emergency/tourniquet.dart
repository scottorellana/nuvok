// Timer de torniquete — protocolo TCCC: la HORA de aplicación se anota
// SIEMPRE. >90 min hay que preparar el relevo médico; >2 h el miembro corre
// riesgo real. Persistido a disco: un reinicio de la app (o cambio de
// teléfono del cuidador vía mesh) no puede perder la hora.
import 'dart:convert';
import 'dart:io';

enum TourniquetSeverity { ok, warning, critical }

class TourniquetRecord {
  const TourniquetRecord({
    required this.id,
    required this.label,
    required this.appliedAt,
  });

  final int id;

  /// Dónde y a quién: "Pierna derecha - Juan".
  final String label;
  final DateTime appliedAt;

  Duration elapsedAt(DateTime now) => now.difference(appliedAt);

  TourniquetSeverity severityAt(DateTime now) {
    final e = elapsedAt(now);
    if (e >= const Duration(hours: 2)) return TourniquetSeverity.critical;
    if (e >= const Duration(minutes: 90)) return TourniquetSeverity.warning;
    return TourniquetSeverity.ok;
  }

  /// Mensaje listo para el canal de emergencia del mesh: quién, dónde y la
  /// HORA EXACTA — el dato que el médico receptor necesita.
  String meshNote() {
    final h = appliedAt.hour.toString().padLeft(2, '0');
    final m = appliedAt.minute.toString().padLeft(2, '0');
    return '🩸 TORNIQUETE: $label — aplicado a las $h:$m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'appliedAt': appliedAt.millisecondsSinceEpoch,
      };

  static TourniquetRecord? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final label = j['label'];
    final at = j['appliedAt'];
    if (id is! int || label is! String || at is! int) return null;
    return TourniquetRecord(
        id: id,
        label: label,
        appliedAt: DateTime.fromMillisecondsSinceEpoch(at));
  }
}

class TourniquetStore {
  TourniquetStore(this.dirPath) {
    _load();
  }

  final String dirPath;
  final List<TourniquetRecord> _active = [];

  List<TourniquetRecord> get active => List.unmodifiable(_active);

  File get _file => File('$dirPath/tourniquets.json');

  void _load() {
    try {
      if (!_file.existsSync()) return;
      final raw = jsonDecode(_file.readAsStringSync());
      if (raw is! List) return;
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final r = TourniquetRecord.fromJson(e);
          if (r != null) _active.add(r);
        }
      }
    } catch (_) {
      // Archivo corrupto: mejor lista vacía que crash en plena emergencia.
    }
  }

  void _save() {
    try {
      Directory(dirPath).createSync(recursive: true);
      _file.writeAsStringSync(
          jsonEncode([for (final t in _active) t.toJson()]));
    } catch (_) {}
  }

  TourniquetRecord start({required String label, DateTime? at}) {
    final now = at ?? DateTime.now();
    final rec = TourniquetRecord(
      id: now.millisecondsSinceEpoch,
      label: label,
      appliedAt: now,
    );
    _active.add(rec);
    _save();
    return rec;
  }

  void remove(int id) {
    _active.removeWhere((t) => t.id == id);
    _save();
  }
}
