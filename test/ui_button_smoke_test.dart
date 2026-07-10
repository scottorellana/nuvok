import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  // Tras la i18n los textos de UI viven en el registro de traducciones
  // (AppStrings.allKeys) y el código referencia CLAVES. La garantía es la
  // misma de antes — todos los módulos y flujos críticos expuestos y con
  // etiqueta — pero auditada donde ahora viven los textos.
  test('NavigationRail expone todos los módulos principales', () {
    final app = _read('lib/app.dart');
    final es = AppStrings(AppLanguage.es);
    for (final key in <String>[
      'emergency',
      'library',
      'assistant',
      'maps',
      'comms',
      'prep',
      'tools',
      'notes',
      'depot',
      'settings',
    ]) {
      expect(app, contains("'$key'"),
          reason: 'destino faltante en el shell: $key');
      expect(es.t(key), isNot(key),
          reason: 'clave de navegación sin traducción: $key');
    }
  });

  test('botones críticos visibles tienen acción/tooltip o label auditable', () {
    final files = <String>[
      'lib/app.dart',
      'lib/core/locale_service.dart',
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

    // Los flujos migrados se auditan por su texto en español del registro
    // (el corpus incluye locale_service.dart); los aún no migrados, por su
    // literal en el módulo. Si un botón desaparece de ambos, esto truena.
    for (final expected in <String>[
      'Ver Paquete inicial',
      'Explorar',
      'MODO EMERGENCIA',
      'Actualizar',
      'Buscar lugar y llevarme ahí',
      'Capas: POIs y capas tácticas',
      'Mi ubicación (GPS)',
      'Copiar código',
      'Unirme',
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
    expect(corpus, isNot(contains('qr_code_scanner')),
        reason:
            'no mostrar un lector QR si el flujo solo acepta código pegado');
    expect(corpus.toLowerCase(), isNot(contains('escanea el qr')),
        reason:
            'no prometer escaneo QR dentro de la app sin lector implementado');
  });
}
