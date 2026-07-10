import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/core/locale_service.dart';
import 'package:prepper_pad/core/prepper_library.dart';

import 'package:prepper_pad/modules/ai/ai_page.dart';
import 'package:prepper_pad/modules/depot/depot_page.dart';
import 'package:prepper_pad/modules/emergency/emergency_page.dart';
import 'package:prepper_pad/modules/library/library_page.dart';
import 'package:prepper_pad/modules/maps/maps_page.dart';
import 'package:prepper_pad/modules/mesh/mesh_page.dart';
import 'package:prepper_pad/modules/notes/notes_page.dart';
import 'package:prepper_pad/modules/prep/checklist_page.dart';
import 'package:prepper_pad/modules/settings/settings_page.dart';
import 'package:prepper_pad/modules/tools/tools_page.dart';
import 'package:prepper_pad/modules/update/update_page.dart';

// Matriz responsive: cada pantalla principal debe montarse y renderizar sin
// overflow ni excepciones de layout en teléfonos (iOS/Android), tablets y
// computadora. Un RenderFlex overflow hace fallar el test automáticamente.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mismo arranque que main(): las páginas dependen de estos singletons.
    await PrepperLibrary.init();
    await PrepperLibrary.instance.ensure();
    LocaleService.instance
        .init(deviceLocale: PlatformDispatcher.instance.locale);
  });

  const sizes = <String, (Size, double)>{
    'iPhone SE (375x667)': (Size(375, 667), 2.0),
    'iPhone (390x844)': (Size(390, 844), 3.0),
    'Android (360x800)': (Size(360, 800), 2.75),
    'Tablet vertical (820x1180)': (Size(820, 1180), 2.0),
    'Tablet horizontal (1180x820)': (Size(1180, 820), 2.0),
    'Computadora (1440x900)': (Size(1440, 900), 1.0),
  };

  final pages = <String, Widget Function()>{
    'Emergencia': () => const EmergencyPage(),
    'Biblioteca': () => const LibraryPage(),
    'Asistente IA': () => const AiPage(),
    'Mapas': () => const MapsPage(),
    'Comunicación': () => const MeshPage(),
    'Preparación': () => const ChecklistPage(),
    'Herramientas': () => const ToolsPage(),
    'Notas': () => const NotesPage(),
    'Depósito': () => DepotPage(initialTab: 0),
    'Ajustes': () => const SettingsPage(),
    // UpdatePage es un widget embebido (vive en Depósito → App, sin Scaffold
    // propio); se envuelve igual que en la app real.
    'Actualizaciones': () =>
        const Scaffold(body: SingleChildScrollView(child: UpdatePage())),
  };

  for (final MapEntry(key: sizeName, value: (size, dpr)) in sizes.entries) {
    for (final MapEntry(key: pageName, value: buildPage) in pages.entries) {
      testWidgets('$pageName renderiza sin overflow en $sizeName',
          (tester) async {
        tester.view.physicalSize = Size(size.width * dpr, size.height * dpr);
        tester.view.devicePixelRatio = dpr;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(home: buildPage()));
        // Frames fijos (no pumpAndSettle): algunas pantallas tienen
        // animaciones continuas o timers que nunca "asientan".
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.byType(Scaffold), findsWidgets,
            reason: '$pageName debe montar su Scaffold en $sizeName');
      });
    }
  }
}
