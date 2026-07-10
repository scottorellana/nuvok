import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/tourniquet.dart';

void main() {
  test('el registro persiste y sobrevive un "reinicio"', () {
    final dir = Directory.systemTemp.createTempSync('tq').path;
    final store = TourniquetStore(dir);
    expect(store.active, isEmpty);

    final t = store.start(
        label: 'Pierna derecha - Juan',
        at: DateTime(2026, 7, 9, 14, 0));
    expect(store.active, hasLength(1));

    // "Reinicio de la app": nueva instancia sobre el mismo directorio.
    final store2 = TourniquetStore(dir);
    expect(store2.active, hasLength(1));
    expect(store2.active.first.label, 'Pierna derecha - Juan');
    expect(store2.active.first.id, t.id);

    store2.remove(t.id);
    expect(TourniquetStore(dir).active, isEmpty);
  });

  test('la severidad escala con el tiempo transcurrido', () {
    final applied = DateTime(2026, 7, 9, 12, 0);
    final t = TourniquetRecord(id: 1, label: 'x', appliedAt: applied);
    expect(t.severityAt(applied.add(const Duration(minutes: 30))),
        TourniquetSeverity.ok);
    expect(t.severityAt(applied.add(const Duration(minutes: 95))),
        TourniquetSeverity.warning); // >90 min: prepara el relevo médico
    expect(t.severityAt(applied.add(const Duration(hours: 2, minutes: 1))),
        TourniquetSeverity.critical); // >2 h: riesgo del miembro
  });

  test('la nota mesh incluye la hora exacta de aplicación', () {
    final t = TourniquetRecord(
        id: 7, label: 'Brazo izq - Ana', appliedAt: DateTime(2026, 7, 9, 9, 41));
    final msg = t.meshNote();
    expect(msg, contains('TORNIQUETE'));
    expect(msg, contains('Brazo izq - Ana'));
    expect(msg, contains('09:41'));
  });
}
