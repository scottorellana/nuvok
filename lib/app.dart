import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'main.dart';
import 'modules/ai/ai_page.dart';
import 'modules/depot/depot_page.dart';
import 'modules/emergency/emergency_page.dart';
import 'modules/library/library_page.dart';
import 'modules/maps/map_focus.dart';
import 'modules/maps/maps_page.dart';
import 'modules/mesh/mesh_envelope.dart';
import 'modules/mesh/mesh_page.dart';
import 'modules/mesh/mesh_router.dart';
import 'modules/mesh/mesh_service.dart';
import 'modules/notes/notes_page.dart';
import 'modules/prep/checklist_page.dart';
import 'modules/tools/tools_page.dart';

class PrepperPadApp extends StatelessWidget {
  const PrepperPadApp({super.key, required this.firstRun});
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8C9E5E), // olive
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Prepper Pad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF14170F),
      ),
      home: AppLifecycleCleanup(child: HomeShell(firstRun: firstRun)),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.firstRun});
  final bool firstRun;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.emergency_outlined, Icons.emergency, 'Emergencia'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Biblioteca'),
    (Icons.psychology_outlined, Icons.psychology, 'Asistente IA'),
    (Icons.map_outlined, Icons.map, 'Mapas'),
    (Icons.cell_tower_outlined, Icons.cell_tower, 'Comunicación'),
    (Icons.checklist_outlined, Icons.checklist, 'Preparación'),
    (Icons.flashlight_on_outlined, Icons.flashlight_on, 'Herramientas'),
    (Icons.edit_note_outlined, Icons.edit_note, 'Notas'),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Depósito'),
  ];

  int _depotInitialTab = 0;
  StreamSubscription<MeshEvent>? _sosSub;
  final Set<String> _sosShownFor = {};

  List<Widget> get _pages => [
        const EmergencyPage(),
        const LibraryPage(),
        const AiPage(),
        const MapsPage(),
        const MeshPage(),
        const ChecklistPage(),
        const ToolsPage(),
        const NotesPage(),
        // Keyed so switching the starter-tab target rebuilds the Depot.
        DepotPage(key: ValueKey(_depotInitialTab), initialTab: _depotInitialTab),
      ];

  @override
  void initState() {
    super.initState();
    if (widget.firstRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcome());
    }
    // The mesh listens from app start (if already onboarded): an SOS from a
    // neighbor must alert you even if you never open the Comunicación tab.
    if (MeshService.instance.hasIdentity) {
      MeshService.instance.start();
    }
    _sosSub = MeshService.instance.events.listen(_onMeshEvent);
  }

  @override
  void dispose() {
    _sosSub?.cancel();
    super.dispose();
  }

  void _onMeshEvent(MeshEvent e) {
    if (e.envelope.type == MeshType.sosCancel) {
      _sosShownFor.remove(e.envelope.senderId);
      return;
    }
    if (e.envelope.type != MeshType.sos) return;
    // One full-screen alert per sender per SOS episode, not per repeat.
    if (!_sosShownFor.add(e.envelope.senderId)) return;
    final lat = (e.payload['lat'] as num?)?.toDouble();
    final lon = (e.payload['lon'] as num?)?.toDouble();
    final note = e.payload['note'] as String? ?? '';
    showDialog<void>(
      context: context,
      barrierColor: Colors.red.withValues(alpha: 0.35),
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        icon: const Icon(Icons.sos, color: Colors.white, size: 56),
        title: Text('¡SOS de ${e.envelope.senderName}!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.isNotEmpty)
              Text('"$note"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              lat != null && lon != null
                  ? 'Posición: ${lat.toStringAsFixed(5)}, '
                      '${lon.toStringAsFixed(5)}'
                  : 'Sin posición GPS (fuera de cobertura)',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar',
                style: TextStyle(color: Colors.white70)),
          ),
          if (lat != null && lon != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade900),
              onPressed: () {
                Navigator.of(context).pop();
                MapFocus.go(LatLng(lat, lon));
                setState(() => _index = 3); // Mapas
              },
              icon: const Icon(Icons.map),
              label: const Text('Ver en mapa'),
            ),
        ],
      ),
    );
  }

  void _showWelcome() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bienvenido a Prepper Pad'),
        content: const SizedBox(
          width: 440,
          child: Text(
            'Tu biblioteca de conocimiento offline vive en la carpeta '
            'PrepperPad de tu usuario. Todo lo que descargues ahí '
            '(Wikipedia, mapas, modelos de IA) funciona sin internet y '
            'puede copiarse a otros dispositivos por USB.\n\n'
            'Te recomendamos empezar por el Paquete inicial: manuales de '
            'primeros auxilios y supervivencia en tu idioma, listos para '
            'usar sin conexión.',
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _index = 8; // Depósito
                _depotInitialTab = 0; // Esenciales
              });
            },
            icon: const Icon(Icons.medical_services, size: 18),
            label: const Text('Ver Paquete inicial'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Explorar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(Icons.backpack,
                      size: 34,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 4),
                  Text('Prepper\nPad',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            destinations: [
              for (final (icon, selectedIcon, label) in _destinations)
                NavigationRailDestination(
                  icon: Icon(icon),
                  selectedIcon: Icon(selectedIcon),
                  label: Text(label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),
    );
  }
}
