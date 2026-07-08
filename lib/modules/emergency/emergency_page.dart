// "Emergencia": big-button access to the bundled life-saving guides, with
// symptom search ("no respira" → RCP) and a large-type reader. Works with
// zero downloads and zero internet — this tab is why the product exists.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/locale_service.dart';
import '../../core/prepper_colors.dart';
import '../maps/maps_page.dart';
import '../mesh/mesh_page.dart';
import '../mesh/mesh_service.dart';
import '../tools/flashlight.dart';
import '../tools/rcp_metronome.dart';
import 'emergency_directory.dart';
import 'emergency_guide_media.dart';
import 'emergency_guides.dart';
import 'medical_diagrams.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  // Guide CONTENT exists in es/en only; default follows the APP language so
  // a French/Chinese user gets English guides, not Spanish. The in-page
  // ES/EN toggle still lets anyone override.
  String _lang =
      LocaleService.instance.language == AppLanguage.es ? 'es' : 'en';
  List<EmergencyGuide> _all = [];
  List<EmergencyGuide> _shown = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _emergencyMode = false; // giant-button panic mode

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await EmergencyGuides.load(_lang);
    _shown = EmergencyGuides.search(_all, _searchCtrl.text);
    if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    if (_emergencyMode) return _buildPanicMode(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guías de Emergencia'),
        actions: [
          FilledButton.icon(
            onPressed: () => setState(() => _emergencyMode = true),
            icon: const Icon(Icons.warning, size: 18),
            label: const Text('MODO EMERGENCIA'),
            style: FilledButton.styleFrom(
                backgroundColor: PrepperColors.emergencyDark),
          ),
          const SizedBox(width: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'es', label: Text('ES')),
              ButtonSegment(value: 'en', label: Text('EN')),
            ],
            selected: {_lang},
            onSelectionChanged: (s) {
              _lang = s.first;
              _load();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                // Quick-access emergency buttons (4 most critical)
                _buildQuickAccess(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: PrepperColors.dimText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _lang == 'es'
                              ? 'Estas guías no sustituyen atención médica '
                                  'profesional.'
                              : 'These guides do not replace professional '
                                  'medical care.',
                          style: const TextStyle(
                              fontSize: 14, color: PrepperColors.dimText),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildEmergencyDirectory(),
                Expanded(
                  child: _shown.isEmpty
                      ? Center(
                          child: Text(_lang == 'es'
                              ? 'Sin resultados — prueba otra palabra'
                              : 'No results — try another word'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisExtent: 96,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _shown.length,
                          itemBuilder: (context, i) {
                            final g = _shown[i];
                            final critical = g.priority <= 1;
                            return Card(
                              color: critical
                                  ? PrepperColors.emergencyDeep
                                      .withValues(alpha: 0.35)
                                  : null,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => _GuideReader(guide: g)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(_iconFor(g.id),
                                          size: 34,
                                          color: critical
                                              ? PrepperColors.emergency
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          g.title,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
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
          color: PrepperColors.emergencyDark,
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
                      color: PrepperColors.white, size: 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _lang == 'es' ? 'MODO EMERGENCIA' : 'EMERGENCY MODE',
                          style: const TextStyle(
                            color: PrepperColors.white,
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
                              color: PrepperColors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward,
                      color: PrepperColors.white, size: 28),
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
                  size: 18, color: PrepperColors.emergency),
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
      leading: const Icon(Icons.phone_in_talk, color: PrepperColors.emergency),
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
                        color: PrepperColors.safe,
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
        color: PrepperColors.emergencyDark,
        ids: ['rcp_adulto', 'rcp_nino_bebe'],
      ),
      _PanicButton(
        icon: Icons.air,
        label: es ? 'ATRAGANTADO' : 'CHOKING',
        color: PrepperColors.caution,
        ids: ['atragantamiento'],
      ),
      _PanicButton(
        icon: Icons.water_drop,
        label: es ? 'SANGRADO\nFUERTE' : 'SEVERE\nBLEEDING',
        color: PrepperColors.emergency,
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
        color: PrepperColors.emergencyDeep,
        ids: ['infarto_acv'],
      ),
    ];

    return Scaffold(
      backgroundColor: PrepperColors.black,
      appBar: AppBar(
        backgroundColor: PrepperColors.black,
        title: Text(
          es
              ? '🚨 EMERGENCIA — toca lo que pasa'
              : '🚨 EMERGENCY — tap what\'s wrong',
          style: const TextStyle(
              color: PrepperColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: PrepperColors.white),
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
                leading: const Icon(Icons.phone, color: PrepperColors.safe),
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
    final widgets = <Widget>[
      _mediaBriefCard(context, media),
      _visualCard(
        context,
        'Resumen visual',
        GuideVisualIllustration(guideId: id),
      ),
    ];

    // CPR guides get the animated compression diagram
    if (id.startsWith('rcp')) {
      widgets
          .add(_visualCard(context, 'Técnica de compresión', CprAnimation()));
    }
    // Choking guides get the Heimlich animation
    if (id.contains('atragant')) {
      widgets.add(_visualCard(
          context, 'Maniobra de Heimlich', const HeimlichAnimation()));
    }
    // Bleeding guides get the tourniquet diagram
    if (id.contains('hemorragia')) {
      widgets.add(_visualCard(
          context, 'Aplicación de torniquete', const TourniquetDiagram()));
      widgets.add(_visualCard(context, 'Posición de recuperación',
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

  Widget _mediaBriefCard(BuildContext context, EmergencyGuideMediaSpec media) {
    final MaterialColor color = media.visualPolicy == VisualPolicy.contextOnly
        ? Colors.indigo
        : Colors.teal;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 132),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.shade900.withValues(alpha: 0.92),
                  color.shade600.withValues(alpha: 0.76),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Icon(_iconForMedia(media.animationKind),
                      color: Colors.white, size: 46),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Imagen fotorealista segura',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        media.visualPolicy == VisualPolicy.contextOnly
                            ? 'Escena contextual: prepara el entorno. La técnica exacta se enseña con animación vectorial.'
                            : 'Escena práctica: muestra el entorno o resultado que debes montar paso a paso.',
                        style:
                            const TextStyle(color: Colors.white, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.photo_camera, size: 18),
                      label: Text(media.title),
                    ),
                    Chip(
                      avatar:
                          const Icon(Icons.movie_creation_outlined, size: 18),
                      label: Text('Animación ${media.animationKind.name}'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  media.safetyNote,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMedia(GuideAnimationKind kind) {
    switch (kind) {
      case GuideAnimationKind.pulse:
        return Icons.monitor_heart;
      case GuideAnimationKind.airway:
        return Icons.air;
      case GuideAnimationKind.bleeding:
        return Icons.water_drop;
      case GuideAnimationKind.burn:
        return Icons.local_fire_department;
      case GuideAnimationKind.splint:
        return Icons.personal_injury;
      case GuideAnimationKind.recognition:
        return Icons.schedule;
      case GuideAnimationKind.protect:
        return Icons.shield;
      case GuideAnimationKind.warmth:
        return Icons.thermostat;
      case GuideAnimationKind.poison:
        return Icons.science;
      case GuideAnimationKind.bite:
        return Icons.pest_control;
      case GuideAnimationKind.temperature:
        return Icons.device_thermostat;
      case GuideAnimationKind.birth:
        return Icons.child_care;
      case GuideAnimationKind.spine:
        return Icons.psychology_alt;
      case GuideAnimationKind.triage:
        return Icons.groups;
      case GuideAnimationKind.kit:
        return Icons.medical_services;
      case GuideAnimationKind.algorithm:
        return Icons.account_tree;
      case GuideAnimationKind.water:
        return Icons.water_drop_outlined;
      case GuideAnimationKind.food:
        return Icons.restaurant;
      case GuideAnimationKind.shelter:
        return Icons.cabin;
      case GuideAnimationKind.navigation:
        return Icons.explore;
      case GuideAnimationKind.signal:
        return Icons.sos;
      case GuideAnimationKind.storm:
        return Icons.thunderstorm;
      case GuideAnimationKind.flood:
        return Icons.flood;
      case GuideAnimationKind.earthquake:
        return Icons.foundation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final aids = _visualAids(context);
    return Scaffold(
      appBar: AppBar(title: Text(guide.title)),
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
      color: PrepperColors.card,
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
                color: PrepperColors.emergencyDark,
                onTap: () => _confirmSos(context),
              ),
              _PanicActionButton(
                icon: Icons.monitor_heart,
                label: _es ? 'RCP' : 'CPR',
                color: PrepperColors.emergency,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const RcpMetronomePage())),
              ),
              _PanicActionButton(
                icon: Icons.flashlight_on,
                label: _es ? 'Linterna' : 'Light',
                color: PrepperColors.caution,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const FlashlightScreen())),
              ),
              _PanicActionButton(
                icon: Icons.phone_in_talk,
                label: _es ? 'Teléfonos' : 'Phones',
                color: PrepperColors.safe,
                onTap: onShowPhones,
              ),
              _PanicActionButton(
                icon: Icons.map,
                label: _es ? 'Mapa' : 'Map',
                color: PrepperColors.olive,
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
        icon: const Icon(Icons.sos, color: PrepperColors.emergency, size: 44),
        title: Text(_es ? '¿Activar SOS?' : 'Activate SOS?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_es
                ? 'Tu posición y esta nota se difundirán cada minuto a todos los Prepper Pad al alcance.'
                : 'Your position and this note will broadcast every minute to nearby Prepper Pads.'),
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
                backgroundColor: PrepperColors.emergencyDark),
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
                  Icon(icon, color: PrepperColors.white, size: 26),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PrepperColors.white,
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
                Icon(button.icon, size: 56, color: PrepperColors.white),
                const SizedBox(height: 8),
                Text(
                  button.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PrepperColors.white,
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
