// "Emergencia": big-button access to the bundled life-saving guides, with
// symptom search ("no respira" → RCP) and a large-type reader. Works with
// zero downloads and zero internet — this tab is why the product exists.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/locale_service.dart';
import '../../core/nuvok_colors.dart';
import '../maps/maps_page.dart';
import '../mesh/mesh_page.dart';
import '../mesh/mesh_service.dart';
import '../tools/flashlight.dart';
import '../tools/rcp_metronome.dart';
import 'emergency_directory.dart';
import 'emergency_guide_media.dart';
import 'emergency_guide_tutorials.dart';
import 'guide_voice.dart';
import 'decision_tree_page.dart';
import 'emergency_call_button.dart';
import 'ice_page.dart';
import 'survival_modes_page.dart';
import 'tourniquet_page.dart';
import 'emergency_guides.dart';
import 'medical_diagrams.dart';

typedef EmergencyGuideLoader = Future<List<EmergencyGuide>> Function(
    String language);

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({
    super.key,
    this.guideLoader = EmergencyGuides.load,
  });

  final EmergencyGuideLoader guideLoader;

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  // Guide bodies and tutorial captions ship in every runtime language. Start
  // in the app language; the in-page selector remains an explicit override.
  String _lang = LocaleService.instance.language.code;
  List<EmergencyGuide> _all = [];
  List<EmergencyGuide> _shown = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _emergencyMode = false; // giant-button panic mode
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final language = _lang;
    final generation = ++_loadGeneration;
    setState(() => _loading = true);
    final guides = await widget.guideLoader(language);
    if (!mounted || generation != _loadGeneration || language != _lang) return;
    setState(() {
      _all = guides;
      _shown = EmergencyGuides.search(guides, _searchCtrl.text);
      _loading = false;
    });
  }

  void _search(String q) {
    setState(() => _shown = EmergencyGuides.search(_all, q));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static IconData _iconFor(String id) {
    if (id.startsWith('rcp')) return Icons.monitor_heart;
    if (id.contains('atragant')) return Icons.air;
    if (id.contains('hemorragia') || id.contains('bleeding')) {
      return Icons.water_drop;
    }
    if (id.contains('quemadura') || id.contains('burn')) {
      return Icons.local_fire_department;
    }
    if (id.contains('fractura') || id.contains('fracture')) {
      return Icons.personal_injury;
    }
    if (id.contains('infarto') || id.contains('heart')) {
      return Icons.favorite;
    }
    if (id.contains('convulsion') || id.contains('seizure')) {
      return Icons.electric_bolt;
    }
    if (id.contains('parto') || id.contains('birth')) {
      return Icons.child_care;
    }
    if (id.contains('mordedura') || id.contains('bite')) {
      return Icons.pest_control;
    }
    if (id.contains('intoxica') || id.contains('poison')) {
      return Icons.science;
    }
    if (id.contains('triaje') || id.contains('triage')) {
      return Icons.groups;
    }
    if (id.contains('botiquin') || id.contains('kit')) {
      return Icons.medical_services;
    }
    if (id.contains('hipotermia') ||
        id.contains('calor') ||
        id.contains('heat') ||
        id.contains('hypo')) {
      return Icons.thermostat;
    }
    if (id.contains('trauma') || id.contains('cabeza') || id.contains('head')) {
      return Icons.psychology_alt;
    }
    if (id.contains('shock')) return Icons.warning;
    return Icons.healing;
  }

  /// Fallback widget for guides without a photorealistic image — shows
  /// the guide icon on a gradient surface so the grid looks consistent.
  Widget _iconFallback(EmergencyGuide g, bool critical) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: critical
              ? [NuvokColors.emergencyDark, NuvokColors.emergencyDeep]
              : [NuvokColors.cardElevated, NuvokColors.card],
        ),
      ),
      child: Center(
        child: Icon(
          _iconFor(g.id),
          size: 48,
          color: critical ? NuvokColors.emergency : NuvokColors.olive,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_emergencyMode) return _buildPanicMode(context);
    // On phone widths the full "MODO EMERGENCIA" button + language selector
    // overflow the AppBar (76px on iPhone). The big CTA below the bar already
    // exists, so in compact mode the action collapses to a warning icon.
    final compactBar = MediaQuery.of(context).size.width < 560;
    return Scaffold(
      appBar: AppBar(
        // Detectado en QA visual: estaba fijo en español y los usuarios de
        // los otros 6 idiomas veían 'Guías de Emergencia' siempre.
        title: Text(tr(context, 'egPageTitle')),
        actions: [
          if (compactBar)
            IconButton(
              tooltip: 'MODO EMERGENCIA',
              onPressed: () => setState(() => _emergencyMode = true),
              icon: const Icon(Icons.warning, color: NuvokColors.emergency),
            )
          else
            FilledButton.icon(
              onPressed: () => setState(() => _emergencyMode = true),
              icon: const Icon(Icons.warning, size: 18),
              label: const Text('MODO EMERGENCIA'),
              style: FilledButton.styleFrom(
                  backgroundColor: NuvokColors.emergencyDark),
            ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey('emergency-guide-language-selector'),
              value: _lang,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final language in AppLanguage.values)
                  DropdownMenuItem<String>(
                    value: language.code,
                    child:
                        Text('${language.flag} ${language.code.toUpperCase()}'),
                  ),
              ],
              onChanged: (lang) {
                if (lang == null || lang == _lang) return;
                setState(() => _lang = lang);
                _load();
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      // Un solo scroll para toda la página: en un iPhone los bloques fijos
      // (CTA, buscador, botones, directorio) consumían casi toda la altura y
      // el grid quedaba aplastado en una franja donde apenas se podía
      // deslizar — en SE directamente desbordaba.
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverList.list(
                  children: [
                    _buildEmergencyModeCta(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: false,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: _lang == 'es'
                              ? '¿Qué está pasando? (ej: no respira, sangrado…)'
                              : 'What is happening? (e.g. not breathing…)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: _search,
                      ),
                    ),
                    // Llamada real al número de emergencias del país (offline
                    // se resuelve el número; la llamada usa la red si vive).
                    const EmergencyCallButton(),
                    // Árbol de decisión estilo 911: convierte pánico en el
                    // procedimiento exacto con una pregunta por pantalla.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          textStyle: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DecisionTreePage(
                              openGuide: (ctx, id) {
                                final g =
                                    _all.where((g) => g.id == id).firstOrNull;
                                if (g == null) return;
                                Navigator.of(ctx).push(MaterialPageRoute(
                                    builder: (_) => _GuideReader(guide: g)));
                              },
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.quiz),
                        label: Text(tr(context, 'dtTitle')),
                      ),
                    ),
                    // Modos de supervivencia: tu entorno especializa la app.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44)),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SurvivalModesPage(
                              openGuide: (ctx, id) {
                                final g =
                                    _all.where((g) => g.id == id).firstOrNull;
                                if (g == null) return;
                                Navigator.of(ctx).push(MaterialPageRoute(
                                    builder: (_) => _GuideReader(guide: g)));
                              },
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.terrain),
                        label: Text('🌲 ${tr(context, 'modesTitle')}'),
                      ),
                    ),
                    // Timer de torniquete: la hora de aplicación salva el miembro.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: Colors.red.shade400,
                        ),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const TourniquetPage())),
                        icon: const Icon(Icons.timer),
                        label: Text('🩸 ${tr(context, 'tqTitle')}'),
                      ),
                    ),
                    // Ficha ICE: habla por ti si estás inconsciente.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44)),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const IcePage())),
                        icon: const Icon(Icons.badge_outlined),
                        label: Text('🆔 ${tr(context, 'iceTitle')}'),
                      ),
                    ),
                    // Quick-access emergency buttons (4 most critical)
                    _buildQuickAccess(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: NuvokColors.dimText),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _lang == 'es'
                                  ? 'Estas guías no sustituyen atención médica '
                                      'profesional.'
                                  : 'These guides do not replace professional '
                                      'medical care.',
                              style: const TextStyle(
                                  fontSize: 14, color: NuvokColors.dimText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildEmergencyDirectory(),
                  ],
                ),
                if (_shown.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: Text(_lang == 'es'
                            ? 'Sin resultados — prueba otra palabra'
                            : 'No results — try another word')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 280,
                        mainAxisExtent: 200,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _shown.length,
                      itemBuilder: (context, i) {
                        final g = _shown[i];
                        final critical = g.priority <= 1;
                        final media = EmergencyGuideMedia.forGuide(g.id);
                        final hasImage = media.imageAssetPath != null;
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          color: critical
                              ? NuvokColors.emergencyDeep
                                  .withValues(alpha: 0.35)
                              : null,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => _GuideReader(guide: g)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Thumbnail: photorealistic image if available,
                                // otherwise icon fallback with gradient.
                                Expanded(
                                  flex: 3,
                                  child: hasImage
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.asset(
                                              media.imageAssetPath!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _iconFallback(g, critical),
                                            ),
                                            if (critical)
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      NuvokColors
                                                          .emergencyDeep
                                                          .withValues(
                                                              alpha: 0.6),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        )
                                      : _iconFallback(g, critical),
                                ),
                                // Title bar
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(_iconFor(g.id),
                                          size: 18,
                                          color: critical
                                              ? NuvokColors.emergency
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          g.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEmergencyModeCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Semantics(
        button: true,
        label:
            'Modo emergencia. Toca aquí si alguien está herido o en peligro.',
        child: Material(
          color: NuvokColors.emergencyDark,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _emergencyMode = true),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded,
                      color: NuvokColors.white, size: 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _lang == 'es' ? 'MODO EMERGENCIA' : 'EMERGENCY MODE',
                          style: const TextStyle(
                            color: NuvokColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lang == 'es'
                              ? 'Toca aquí si alguien está herido o en peligro.'
                              : 'Tap here if someone is hurt or in danger.',
                          style: const TextStyle(
                              color: NuvokColors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward,
                      color: NuvokColors.white, size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Quick-access row with the 4 most critical emergencies.
  Widget _buildQuickAccess() {
    final criticalIds = _lang == 'es'
        ? ['rcp_adulto', 'atragantamiento', 'hemorragia_severa', 'shock']
        : ['rcp_adulto', 'atragantamiento', 'hemorragia_severa', 'shock'];
    final quickGuides = criticalIds
        .map((id) {
          return _all.where((g) => g.id == id).firstOrNull;
        })
        .whereType<EmergencyGuide>()
        .toList();

    if (quickGuides.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      // Wrap (not Row): on a narrow phone the label + 4 chips don't fit on one
      // line — a Row overflowed by ~110px. Wrapping keeps every chip reachable.
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              _lang == 'es' ? 'Acceso rápido:' : 'Quick access:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          for (final g in quickGuides)
            ActionChip(
              label: Text(_shortLabel(g.id, _lang)),
              avatar: Icon(_iconFor(g.id),
                  size: 18, color: NuvokColors.emergency),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => _GuideReader(guide: g)),
              ),
            ),
        ],
      ),
    );
  }

  String _shortLabel(String id, String lang) {
    final es = lang == 'es';
    if (id.startsWith('rcp')) return es ? 'RCP' : 'CPR';
    if (id.contains('atragant')) return es ? 'Atraganta' : 'Choking';
    if (id.contains('hemorragia')) return es ? 'Sangrado' : 'Bleeding';
    if (id.contains('shock')) return 'Shock';
    return id;
  }

  String? _selectedCountry;

  Widget _buildEmergencyDirectory() {
    final countries =
        emergencyDirectory.where((c) => c.countryCode != '*').toList();
    final current = emergencyNumbersFor(_selectedCountry);

    return ExpansionTile(
      leading: const Icon(Icons.phone_in_talk, color: NuvokColors.emergency),
      title: Text(
        _lang == 'es' ? 'Teléfonos de emergencia' : 'Emergency numbers',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${current.flag} ${current.countryName}'),
      children: [
        // Country selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButton<String>(
            value: _selectedCountry,
            hint: Text(
                _lang == 'es' ? 'Selecciona tu país' : 'Select your country'),
            isExpanded: true,
            items: [
              for (final c in countries)
                DropdownMenuItem(
                  value: c.countryCode,
                  child: Text('${c.flag} ${c.countryName}'),
                ),
            ],
            onChanged: (v) => setState(() => _selectedCountry = v),
          ),
        ),
        // Service numbers
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              for (final s in current.services)
                ListTile(
                  dense: true,
                  leading: Icon(_iconForService(s.name),
                      size: 24, color: Theme.of(context).colorScheme.primary),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (s.description != null)
                        Text(
                          s.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.number,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.phone, size: 20),
                        color: NuvokColors.safe,
                        tooltip: _lang == 'es' ? 'Llamar' : 'Call',
                        onPressed: () {
                          // Copy number to clipboard — the app can't dial
                          // directly on all platforms, but the user can paste.
                          final number =
                              s.number.replaceAll(RegExp(r'[^0-9+]'), '');
                          Clipboard.setData(ClipboardData(text: number));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(_lang == 'es'
                                  ? 'Número copiado: $number — pégalo en el teléfono'
                                  : 'Number copied: $number')));
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconForService(String name) {
    final n = name.toLowerCase();
    if (n.contains('bomber')) return Icons.local_fire_department;
    if (n.contains('polic')) return Icons.local_police;
    if (n.contains('cruz roja') || n.contains('red cross')) {
      return Icons.health_and_safety;
    }
    if (n.contains('médic') || n.contains('medical')) {
      return Icons.medical_services;
    }
    if (n.contains('civil') || n.contains('riesgo') || n.contains('desastre')) {
      return Icons.warehouse;
    }
    if (n.contains('suicid') || n.contains('poison') || n.contains('envenen')) {
      return Icons.warning;
    }
    return Icons.phone;
  }

  /// Full-screen panic mode: giant buttons for the most common emergencies,
  /// high contrast, accessible with trembling hands.
  Widget _buildPanicMode(BuildContext context) {
    final es = _lang == 'es';
    final entries = <_PanicButton>[
      _PanicButton(
        icon: Icons.monitor_heart,
        label: es ? 'NO RESPIRA\n(RCP)' : 'NOT BREATHING\n(CPR)',
        color: NuvokColors.emergencyDark,
        ids: ['rcp_adulto', 'rcp_nino_bebe'],
      ),
      _PanicButton(
        icon: Icons.air,
        label: es ? 'ATRAGANTADO' : 'CHOKING',
        color: NuvokColors.caution,
        ids: ['atragantamiento'],
      ),
      _PanicButton(
        icon: Icons.water_drop,
        label: es ? 'SANGRADO\nFUERTE' : 'SEVERE\nBLEEDING',
        color: NuvokColors.emergency,
        ids: ['hemorragia_severa'],
      ),
      _PanicButton(
        icon: Icons.local_fire_department,
        label: es ? 'QUEMADURA' : 'BURN',
        color: const Color(0xFFD84315),
        ids: ['quemaduras'],
      ),
      _PanicButton(
        icon: Icons.personal_injury,
        label: es ? 'FRACTURA\n/ GOLPE' : 'FRACTURE\n/ INJURY',
        color: Colors.brown,
        ids: ['fracturas_inmovilizacion', 'trauma_cabeza_columna'],
      ),
      _PanicButton(
        icon: Icons.favorite,
        label: es ? 'INFARTO\n/ DERRAME' : 'HEART\nATTACK',
        color: NuvokColors.emergencyDeep,
        ids: ['infarto_acv'],
      ),
    ];

    return Scaffold(
      backgroundColor: NuvokColors.black,
      appBar: AppBar(
        backgroundColor: NuvokColors.black,
        title: Text(
          es
              ? '🚨 EMERGENCIA — toca lo que pasa'
              : '🚨 EMERGENCY — tap what\'s wrong',
          style: const TextStyle(
              color: NuvokColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: NuvokColors.white),
            onPressed: () => setState(() => _emergencyMode = false),
            tooltip: es ? 'Salir' : 'Exit',
          ),
        ],
      ),
      body: Column(
        children: [
          _PanicActionBar(
              lang: _lang, onShowPhones: _showEmergencyNumbersSheet),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              padding: const EdgeInsets.all(8),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final b in entries)
                  _PanicButtonWidget(
                    button: b,
                    guides: _all,
                    lang: _lang,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyNumbersSheet() {
    final current = emergencyNumbersFor(_selectedCountry);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
                _lang == 'es' ? 'Teléfonos de emergencia' : 'Emergency numbers',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final s in current.services)
              ListTile(
                leading: const Icon(Icons.phone, color: NuvokColors.safe),
                title: Text(s.name),
                subtitle: s.description == null ? null : Text(s.description!),
                trailing: Text(s.number,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                minVerticalPadding: 14,
                onTap: () {
                  final number = s.number.replaceAll(RegExp(r'[^0-9+]'), '');
                  Clipboard.setData(ClipboardData(text: number));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Número copiado: $number')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GuideReader extends StatelessWidget {
  const _GuideReader({required this.guide});
  final EmergencyGuide guide;

  /// Returns widgets to display before specific sections based on guide id.
  List<Widget> _visualAids(BuildContext context) {
    final id = guide.id;
    final media = EmergencyGuideMedia.forGuide(id);
    final widgets = <Widget>[];

    // Hero image — full-width, no card wrapper, no developer metadata.
    if (media.imageAssetPath != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            label: media.imageAltText,
            image: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                media.imageAssetPath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    }

    // Critical steps card — the most useful visual element in the reader.
    // Shows numbered action steps extracted from the guide's markdown body,
    // plus "what NOT to do" warnings. Replaces the old generic vector animation.
    widgets.add(CriticalStepsCard(
      title: guide.title,
      body: guide.body,
    ));

    final tutorial = EmergencyGuideTutorials.forGuide(id);
    if (tutorial != null) {
      widgets.add(_GuideTutorialCard(tutorial: tutorial, lang: guide.lang));
    }

    // Imágenes de paso adicionales (2-3 por guía en los paquetes nuevos).
    for (final (path, alt) in EmergencyGuideMedia.extraImagesFor(id)) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            label: alt,
            image: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    }

    // CPR guides get the animated compression diagram
    if (id.startsWith('rcp')) {
      widgets.add(_visualCard(context,
          _guideReaderLabel(id, 'Técnica de compresión'), CprAnimation()));
    }
    // Choking guides get the Heimlich animation
    if (id.contains('atragant')) {
      widgets.add(_visualCard(
          context,
          _guideReaderLabel(id, 'Maniobra de Heimlich'),
          const HeimlichAnimation()));
    }
    // Bleeding guides get the tourniquet diagram
    if (id.contains('hemorragia')) {
      widgets.add(_visualCard(
          context,
          _guideReaderLabel(id, 'Aplicación de torniquete'),
          const TourniquetDiagram()));
      widgets.add(_visualCard(
          context,
          _guideReaderLabel(id, 'Posición de recuperación'),
          const RecoveryPositionDiagram()));
    }
    // Burn guides get the severity chart
    if (id.contains('quemadura')) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(const BurnSeverityChart());
    }
    // Bite/sting guides
    if (id.contains('mordedura') || id.contains('picadura')) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(const BiteStingComparison());
    }
    // Triage
    if (id.contains('triaje')) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(const TriageFlowchart());
    }
    return widgets;
  }

  /// Localized section titles in the guide reader.
  String _guideReaderLabel(String id, String fallback) {
    // The reader doesn't have lang context; use the guide's lang field.
    final es = guide.lang == 'es';
    if (fallback.contains('compresión')) {
      return es ? 'Técnica de compresión' : 'Compression technique';
    }
    if (fallback.contains('Heimlich')) {
      return es ? 'Maniobra de Heimlich' : 'Heimlich maneuver';
    }
    if (fallback.contains('torniquete')) {
      return es ? 'Aplicación de torniquete' : 'Tourniquet application';
    }
    if (fallback.contains('recuperación')) {
      return es ? 'Posición de recuperación' : 'Recovery position';
    }
    if (fallback.contains('Resumen')) {
      return es ? 'Resumen visual' : 'Visual summary';
    }
    return fallback;
  }

  Widget _visualCard(BuildContext context, String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aids = _visualAids(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(guide.title),
        actions: [
          // RCP: el metrónomo de compresiones a un toque desde la guía.
          if (guide.id.startsWith('rcp'))
            IconButton(
              tooltip: tr(context, 'rcpMetronome'),
              icon: const Icon(Icons.music_note),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RcpMetronomePage())),
            ),
          // Manos libres: lee el título y los pasos críticos en voz alta.
          ValueListenableBuilder<bool>(
            valueListenable: GuideVoice.instance.speaking,
            builder: (context, speaking, _) => IconButton(
              tooltip: tr(context, speaking ? 'voiceStopRead' : 'voiceRead'),
              icon: Icon(speaking ? Icons.stop_circle : Icons.record_voice_over,
                  color: speaking ? Colors.red : null),
              onPressed: () => GuideVoice.instance.speakSteps(
                title: guide.title,
                steps: extractCriticalSteps(guide.body),
                appLangCode: LocaleService.instance.language.code,
              ),
            ),
          ),
        ],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Visual aids appear at the top, before the text
                if (aids.isNotEmpty) ...aids,
                // Guide content
                HtmlWidget(
                  md.markdownToHtml(guide.body,
                      extensionSet: md.ExtensionSet.gitHubFlavored),
                  textStyle: const TextStyle(fontSize: 17, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideTutorialCard extends StatelessWidget {
  const _GuideTutorialCard({required this.tutorial, required this.lang});

  final EmergencyGuideTutorial tutorial;
  final String lang;

  bool get _es => lang == 'es';

  @override
  Widget build(BuildContext context) {
    final semanticLabel =
        tutorial.steps.map((step) => step.altFor(lang)).join('. ');

    return Card(
      key: ValueKey('guide-tutorial-${tutorial.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  const Icon(Icons.photo_library_outlined,
                      color: NuvokColors.caution),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _es
                          ? 'Tutorial visual · 3 pasos'
                          : 'Visual tutorial · 3 steps',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (constraints.maxWidth >= 400)
                    Text(
                      _es ? 'Toca para ampliar' : 'Tap to enlarge',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: semanticLabel,
              image: true,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showZoom(context, semanticLabel),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    tutorial.assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: NuvokColors.cardElevated,
                      alignment: Alignment.center,
                      child: Text(_es
                          ? 'Tutorial visual no disponible'
                          : 'Visual tutorial unavailable'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final step in tutorial.steps) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: NuvokColors.caution,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${step.number}',
                      style: const TextStyle(
                        color: NuvokColors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        step.captionFor(lang),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (step.number < tutorial.steps.length)
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  void _showZoom(BuildContext context, String semanticLabel) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: NuvokColors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Semantics(
              label: semanticLabel,
              image: true,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.asset(
                  tutorial.assetPath,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filled(
                tooltip: _es ? 'Cerrar' : 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panic mode — giant buttons for emergencies
// ─────────────────────────────────────────────────────────────────────────────

class _PanicActionBar extends StatelessWidget {
  const _PanicActionBar({required this.lang, required this.onShowPhones});

  final String lang;
  final VoidCallback onShowPhones;

  bool get _es => lang == 'es';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NuvokColors.card,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: [
              _PanicActionButton(
                icon: Icons.sos,
                label: 'SOS',
                color: NuvokColors.emergencyDark,
                onTap: () => _confirmSos(context),
              ),
              _PanicActionButton(
                icon: Icons.monitor_heart,
                label: _es ? 'RCP' : 'CPR',
                color: NuvokColors.emergency,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const RcpMetronomePage())),
              ),
              _PanicActionButton(
                icon: Icons.flashlight_on,
                label: _es ? 'Linterna' : 'Light',
                color: NuvokColors.caution,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const FlashlightScreen())),
              ),
              _PanicActionButton(
                icon: Icons.phone_in_talk,
                label: _es ? 'Teléfonos' : 'Phones',
                color: NuvokColors.safe,
                onTap: onShowPhones,
              ),
              _PanicActionButton(
                icon: Icons.map,
                label: _es ? 'Mapa' : 'Map',
                color: NuvokColors.olive,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const MapsPage())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSos(BuildContext context) async {
    final service = MeshService.instance;
    if (!service.hasIdentity) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MeshPage()),
      );
      return;
    }
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sos, color: NuvokColors.emergency, size: 44),
        title: Text(_es ? '¿Activar SOS?' : 'Activate SOS?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_es
                ? 'Tu posición y esta nota se difundirán cada minuto a todos los Nuvok al alcance.'
                : 'Your position and this note will broadcast every minute to nearby Nuvoks.'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                labelText: _es ? 'Nota opcional' : 'Optional note',
                hintText: _es ? '¿Qué pasa?' : 'What is happening?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_es ? 'Cancelar' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: NuvokColors.emergencyDark),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ACTIVAR SOS'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await service.startSos(note: noteCtrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_es ? 'SOS activado' : 'SOS activated')),
        );
      }
    }
  }
}

class _PanicActionButton extends StatelessWidget {
  const _PanicActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 64,
              width: 96,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 2),
                  Icon(icon, color: NuvokColors.white, size: 26),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NuvokColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanicButton {
  const _PanicButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.ids,
  });
  final IconData icon;
  final String label;
  final Color color;
  final List<String> ids; // guide ids to try in order
}

class _PanicButtonWidget extends StatelessWidget {
  const _PanicButtonWidget({
    required this.button,
    required this.guides,
    required this.lang,
  });
  final _PanicButton button;
  final List<EmergencyGuide> guides;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: button.label.replaceAll('\n', ' '),
      child: Material(
        color: button.color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Find the first matching guide
            EmergencyGuide? match;
            for (final id in button.ids) {
              match = guides.where((g) => g.id == id).firstOrNull;
              if (match != null) break;
            }
            // Fallback: search by keywords in the label
            if (match == null) {
              final words =
                  button.label.replaceAll('\n', ' ').toLowerCase().split(' ');
              for (final g in guides) {
                if (words.any((w) => g.keywords.any((k) => k.contains(w)))) {
                  match = g;
                  break;
                }
              }
            }
            if (match != null) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _GuideReader(guide: match!),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Contraste según el fondo: blanco fijo sobre el naranja de
                // 'caution' daba 1.87:1 — ilegible bajo sol o con la pantalla
                // atenuada al mínimo, que es justo cuando se usa el pánico.
                Icon(button.icon,
                    size: 56, color: NuvokColors.onColor(button.color)),
                const SizedBox(height: 8),
                Text(
                  button.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NuvokColors.onColor(button.color),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
