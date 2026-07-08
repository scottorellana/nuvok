import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/mesh_identity.dart';

// La identidad automática es lo que hace que TODO Prepper Pad esté en el mesh
// desde que se instala, sin que el usuario tenga que configurar nada — en una
// emergencia nadie debe ser invisible por no haber abierto Comunicación.
void main() {
  test('auto() crea identidad con nombre humano derivado del id', () {
    final a = MeshIdentity.auto();
    expect(a.id.length, 16, reason: 'id de 16 hex como el resto');
    expect(a.name, startsWith('Prepper-'),
        reason: 'nombre reconocible sin pedir nada al usuario');
    // El sufijo del nombre son los últimos 4 hex del id → estable y visible.
    expect(a.name, endsWith(a.id.substring(a.id.length - 4).toUpperCase()));
  });

  test('auto() genera ids distintos cada vez', () {
    final ids = {for (var i = 0; i < 50; i++) MeshIdentity.auto().id};
    expect(ids.length, 50, reason: 'sin colisiones — id aleatorio seguro');
  });

  test('ensureAuto persiste una sola identidad y la reusa', () {
    final tmp = Directory.systemTemp.createTempSync('ident');
    addTearDown(() => tmp.deleteSync(recursive: true));
    expect(MeshIdentity.load(tmp.path), isNull);

    final first = MeshIdentity.ensureAuto(tmp.path);
    expect(first.name, startsWith('Prepper-'));
    // Segunda llamada: MISMA identidad (no re-mintea en cada arranque).
    final second = MeshIdentity.ensureAuto(tmp.path);
    expect(second.id, first.id);
    expect(second.name, first.name);
    // Y quedó en disco para el próximo arranque.
    expect(MeshIdentity.load(tmp.path)!.id, first.id);
  });
}
