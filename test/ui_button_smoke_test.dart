import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('NavigationRail expone todos los módulos principales', () {
    final app = _read('lib/app.dart');
    for (final label in <String>[
      'Emergencia',
      'Biblioteca',
      'Asistente IA',
      'Mapas',
      'Comunicación',
      'Preparación',
      'Herramientas',
      'Notas',
      'Depósito',
    ]) {
      expect(app, contains("'$label'"), reason: 'destino faltante: $label');
    }
  });

  test('botones críticos visibles tienen acción/tooltip o label auditable', () {
    final files = <String>[
      'lib/app.dart',
      'lib/modules/emergency/emergency_page.dart',
      'lib/modules/library/library_page.dart',
      'lib/modules/library/zim_reader_page.dart',
      'lib/modules/maps/maps_page.dart',
      'lib/modules/mesh/mesh_page.dart',
      'lib/modules/notes/notes_page.dart',
      'lib/modules/depot/depot_page.dart',
      'lib/modules/tools/tools_page.dart',
      'lib/modules/update/update_page.dart',
    ];
    final corpus = files.map(_read).join('\n');

    for (final expected in <String>[
      'Ver Paquete inicial',
      'Explorar',
      'MODO EMERGENCIA',
      'Actualizar',
      'Buscar lugar y llevarme ahí',
      'Capas: POIs y capas tácticas',
      'Mi ubicación (GPS)',
      'Copiar código',
      'Unirse',
      'Crear',
      'ACTIVAR SOS',
      'Nueva nota',
      'Descargar todos los paquetes',
      'Región personalizada',
      'Importar',
      'Por URL',
      'Buscar',
      'Instalar ahora',
    ]) {
      expect(corpus, contains(expected),
          reason: 'flujo/botón no auditado: $expected');
    }

    expect(corpus, isNot(contains('debugPrint(')),
        reason: 'no dejar trazas de QA en producción');
  });
}
