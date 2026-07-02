import 'package:flutter/material.dart';

import 'main.dart';
import 'modules/ai/ai_page.dart';
import 'modules/depot/depot_page.dart';
import 'modules/library/library_page.dart';
import 'modules/maps/maps_page.dart';
import 'modules/notes/notes_page.dart';

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
    (Icons.menu_book_outlined, Icons.menu_book, 'Biblioteca'),
    (Icons.psychology_outlined, Icons.psychology, 'Asistente IA'),
    (Icons.map_outlined, Icons.map, 'Mapas'),
    (Icons.edit_note_outlined, Icons.edit_note, 'Notas'),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Depósito'),
  ];

  final _pages = const [
    LibraryPage(),
    AiPage(),
    MapsPage(),
    NotesPage(),
    DepotPage(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.firstRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcome());
    }
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
            'Para empezar, ve al Depósito y descarga contenido — o copia '
            'archivos .zim, .pmtiles o .gguf que ya tengas dentro de la '
            'carpeta PrepperPad.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _index = 4); // Depósito
            },
            child: const Text('Ir al Depósito'),
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
