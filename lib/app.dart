import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/semantics.dart';
import 'package:latlong2/latlong.dart';

import 'core/locale_service.dart';
import 'core/nuvok_colors.dart';
import 'core/shell_nav.dart';
import 'main.dart';
import 'modules/ai/ai_page.dart';
import 'modules/depot/depot_page.dart';
import 'modules/depot/first_run_setup.dart';
import 'modules/emergency/emergency_page.dart';
import 'modules/emergency/sos_alarm.dart';
import 'modules/library/library_page.dart';
import 'modules/maps/map_focus.dart';
import 'modules/maps/maps_page.dart';
import 'modules/mesh/mesh_envelope.dart';
import 'modules/mesh/mesh_page.dart';
import 'modules/mesh/mesh_router.dart';
import 'modules/mesh/mesh_service.dart';
import 'modules/notes/notes_page.dart';
import 'modules/prep/checklist_page.dart';
import 'modules/settings/settings_page.dart';
import 'modules/tools/battery_saver.dart';
import 'modules/tools/tools_page.dart';
import 'modules/update/update_page.dart';

class NuvokApp extends StatelessWidget {
  const NuvokApp({super.key, required this.firstRun});
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8C9E5E), // olive
      brightness: Brightness.dark,
    );

    // Rebuild the whole MaterialApp when the language changes so both our
    // strings AND the system widget chrome (dialogs, pickers) switch at once.
    return ListenableBuilder(
      listenable: LocaleService.instance,
      builder: (context, _) => MaterialApp(
      title: 'Nuvok',
      debugShowCheckedModeBanner: false,
      locale: LocaleService.instance.locale,
      supportedLocales: [
        for (final l in AppLanguage.values) Locale(l.code),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Kreyòl has no Flutter Material translations: system chrome falls
      // back to French (Haiti's other official language); our own strings
      // do render in Kreyòl.
      localeResolutionCallback: (locale, supported) {
        final code = locale?.languageCode;
        if (code == 'ht') return const Locale('fr');
        for (final s in supported) {
          if (s.languageCode == code) return s;
        }
        return const Locale('es');
      },
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: NuvokColors.background,
        // Tablet-optimized: larger touch targets and text
        visualDensity: VisualDensity.standard,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
          bodySmall: TextStyle(fontSize: 14),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(fontSize: 16),
        ),
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 52),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: LocaleProvider(
        service: LocaleService.instance,
        child: AppLifecycleCleanup(child: HomeShell(firstRun: firstRun)),
      ),
      ),
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

  // Navigation labels are string KEYS resolved through AppStrings at build
  // time, so switching the language relabels the whole shell instantly.
  // Barra inferior de móvil: máx 5 (4 módulos + "Más"), según Material 3. El
  // Asistente IA (índice 2) es ahora un módulo estrella, así que va en la
  // barra; Herramientas baja a "Más" (sigue a un toque). SOS/Comunicación se
  // queda en la barra por ser crítico.
  static const _mobileDestinationDefs = [
    (0, Icons.emergency_outlined, Icons.emergency, 'emergency'),
    (2, Icons.psychology_outlined, Icons.psychology, 'assistant'),
    (3, Icons.map_outlined, Icons.map, 'maps'),
    (4, Icons.cell_tower_outlined, Icons.cell_tower, 'comms'),
  ];

  static const _destinationDefs = [
    (Icons.emergency_outlined, Icons.emergency, 'emergency'),
    (Icons.menu_book_outlined, Icons.menu_book, 'library'),
    (Icons.psychology_outlined, Icons.psychology, 'assistant'),
    (Icons.map_outlined, Icons.map, 'maps'),
    (Icons.cell_tower_outlined, Icons.cell_tower, 'comms'),
    (Icons.checklist_outlined, Icons.checklist, 'prep'),
    (Icons.flashlight_on_outlined, Icons.flashlight_on, 'tools'),
    (Icons.edit_note_outlined, Icons.edit_note, 'notes'),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'depot'),
    (Icons.settings_outlined, Icons.settings, 'settings'),
  ];

  List<(int, IconData, IconData, String)> _mobileDestinations(
          AppStrings s) =>
      [
        for (final (i, a, b, key) in _mobileDestinationDefs)
          (i, a, b, s.t(key)),
      ];

  List<(IconData, IconData, String)> _destinations(AppStrings s) => [
        for (final (a, b, key) in _destinationDefs) (a, b, s.t(key)),
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
        DepotPage(
            key: ValueKey(_depotInitialTab), initialTab: _depotInitialTab),
        const SettingsPage(),
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
    // Cross-module jumps (e.g. empty Library → Depósito → Esenciales).
    ShellNav.request.addListener(_onShellNav);
  }

  void _onShellNav() {
    final req = ShellNav.request.value;
    if (req == null || !mounted) return;
    ShellNav.request.value = null;
    setState(() {
      _index = req.moduleIndex;
      if (req.depotTab != null) _depotInitialTab = req.depotTab!;
    });
  }

  @override
  void dispose() {
    ShellNav.request.removeListener(_onShellNav);
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
    final s = LocaleProvider.of(context);
    final sosLabel = '${s.t('sosFrom')} ${e.envelope.senderName}'
        '${note.isNotEmpty ? '. $note' : ''}'
        '${lat != null && lon != null ? '. ${s.t('position')}: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}' : '. ${s.t('noGps')}'}';
    // Announce to screen readers — also wrapped in Semantics(liveRegion) below.
    // ignore: deprecated_member_use
    // SendAnnouncement is wrapped in try/catch so the alert overlay still
    // shows up even in unit tests without TestWidgetsFlutterBinding.
    try {
      // ignore: deprecated_member_use
      SemanticsService.announce(sosLabel, TextDirection.ltr);
    } catch (_) {}
    showDialog<void>(
      context: context,
      barrierColor: Colors.red.withValues(alpha: 0.35),
      builder: (context) => Semantics(
        liveRegion: true,
        label: sosLabel,
        child: AlertDialog(
          backgroundColor: Colors.red.shade900,
          icon: const Icon(Icons.sos, color: Colors.white, size: 56),
          title: Text('${s.t('sosFrom')} ${e.envelope.senderName}',
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
                    ? '${s.t('position')}: ${lat.toStringAsFixed(5)}, '
                        '${lon.toStringAsFixed(5)}'
                    : s.t('noGps'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  Text(s.close, style: const TextStyle(color: Colors.white)),
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
                label: Text(s.t('viewOnMap')),
              ),
          ],
        ),
      ),
    );
  }

  void _showWelcome() {
    // El instalador ligero llega sin IA/mapas/enciclopedia: el primer
    // arranque abre "Prepara tu Nuvok", que propone descargarlos mientras
    // hay internet. Reemplaza al antiguo diálogo de bienvenida.
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const FirstRunSetupPage(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SosAlarmWrapper(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          if (compact) return _buildCompactShell(context);
          return _buildWideShell(context);
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _LowBatteryBanner(
          onOpenSaver: () => setState(() => _index = 6), // Herramientas
        ),
        UpdateBanner(
          onOpen: () => setState(() {
            _index = 8; // Depósito
            _depotInitialTab = 5; // App
          }),
        ),
        Expanded(child: IndexedStack(index: _index, children: _pages)),
      ],
    );
  }

  Widget _buildWideShell(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // The rail has many destinations; on a short window it must scroll,
          // otherwise the last items get clipped and become unreachable.
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
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
                          Text('Nuvok\nPad',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                    destinations: [
                      for (final (icon, selectedIcon, label)
                          in _destinations(LocaleProvider.of(context)))
                        NavigationRailDestination(
                          icon: Icon(icon),
                          selectedIcon: Icon(selectedIcon),
                          label: Text(label),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildCompactShell(BuildContext context) {
    final strings = LocaleProvider.of(context);
    final mobile = _mobileDestinations(strings);
    final selected = mobile.indexWhere((d) => d.$1 == _index);
    return Scaffold(
      body: _buildMainContent(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected >= 0 ? selected : mobile.length,
        onDestinationSelected: (i) {
          if (i < mobile.length) {
            setState(() => _index = mobile[i].$1);
          } else {
            _showMoreModules(context);
          }
        },
        destinations: [
          for (final (_, icon, selectedIcon, label) in mobile)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selectedIcon),
              label: label,
            ),
          NavigationDestination(
            icon: const Icon(Icons.apps_outlined),
            selectedIcon: const Icon(Icons.apps),
            label: strings.t('more'),
          ),
        ],
      ),
    );
  }

  void _showMoreModules(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final all = _destinations(LocaleProvider.of(context));
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(LocaleProvider.of(context).t('moreModules'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (var i = 0; i < all.length; i++)
                ListTile(
                  leading: Icon(all[i].$1),
                  selected: _index == i,
                  title: Text(all[i].$3),
                  minVerticalPadding: 14,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _index = i);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A thin red bar that appears app-wide when the real battery is low and not
/// charging, nudging the user to open the battery saver — in an emergency,
/// running out of charge unnoticed is a real risk.
class _LowBatteryBanner extends StatelessWidget {
  const _LowBatteryBanner({required this.onOpenSaver});
  final VoidCallback onOpenSaver;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BatterySaverController.instance,
      builder: (context, _) {
        final b = BatterySaverController.instance;
        if (!b.isLow || b.enabled) return const SizedBox.shrink();
        final s = LocaleProvider.of(context);
        final lowBatteryMsg =
            '${s.t('lowBattery')} (${b.batteryLevel}%). ${s.t('lowBatteryHint')}';
        return Semantics(
          liveRegion: true,
          label: lowBatteryMsg,
          child: Material(
            color: Colors.red.shade900,
            child: InkWell(
              onTap: onOpenSaver,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.battery_alert,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lowBatteryMsg,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenSaver,
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      child: Text(s.open.toUpperCase()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
