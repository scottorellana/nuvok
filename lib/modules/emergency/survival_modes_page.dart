// Modos de Supervivencia: cuadrícula de entornos → paquete de guías del
// entorno + activación. El modo activo especializa la IA y destaca el
// paquete en toda la app.
import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import 'emergency_guides.dart';
import 'survival_mode.dart';

class SurvivalModesPage extends StatefulWidget {
  const SurvivalModesPage({super.key, required this.openGuide});

  /// Abre una guía por id usando el lector de emergency_page.
  final void Function(BuildContext context, String guideId) openGuide;

  @override
  State<SurvivalModesPage> createState() => _SurvivalModesPageState();
}

class _SurvivalModesPageState extends State<SurvivalModesPage> {
  List<EmergencyGuide> _all = const [];

  @override
  void initState() {
    super.initState();
    EmergencyGuides.load(LocaleService.instance.language.code).then((g) {
      if (mounted) setState(() => _all = g);
    });
  }

  List<EmergencyGuide> _packOf(SurvivalMode m) =>
      [for (final g in _all) if (g.modes.contains(m.name)) g];

  @override
  Widget build(BuildContext context) {
    final active = SurvivalModeStore.active;
    final modes =
        SurvivalMode.values.where((m) => m != SurvivalMode.none).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'modesTitle'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(tr(context, 'modesIntro'),
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount:
                  MediaQuery.of(context).size.width > 560 ? 4 : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: [
                for (final m in modes)
                  Card(
                    color: m == active
                        ? Colors.green.withValues(alpha: 0.25)
                        : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openMode(m),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(m.emoji,
                                style: const TextStyle(fontSize: 36)),
                            const SizedBox(height: 6),
                            Text(
                              tr(context, m.nameKey),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_packOf(m).length} 📖',
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                            if (m == active)
                              Text(tr(context, 'modeActive'),
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openMode(SurvivalMode m) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ModeDetailPage(
        mode: m,
        pack: _packOf(m),
        openGuide: widget.openGuide,
        onChanged: () => setState(() {}),
      ),
    ));
  }
}

class _ModeDetailPage extends StatefulWidget {
  const _ModeDetailPage({
    required this.mode,
    required this.pack,
    required this.openGuide,
    required this.onChanged,
  });

  final SurvivalMode mode;
  final List<EmergencyGuide> pack;
  final void Function(BuildContext, String) openGuide;
  final VoidCallback onChanged;

  @override
  State<_ModeDetailPage> createState() => _ModeDetailPageState();
}

class _ModeDetailPageState extends State<_ModeDetailPage> {
  @override
  Widget build(BuildContext context) {
    final m = widget.mode;
    final active = SurvivalModeStore.active == m;
    return Scaffold(
      appBar:
          AppBar(title: Text('${m.emoji} ${tr(context, m.nameKey)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: active ? Colors.green.shade800 : null,
            ),
            onPressed: () async {
              await SurvivalModeStore.setActive(
                  active ? SurvivalMode.none : m);
              widget.onChanged();
              if (mounted) setState(() {});
            },
            icon: Icon(active ? Icons.check_circle : Icons.explore),
            label: Text(tr(
                context, active ? 'modeDeactivate' : 'modeActivate')),
          ),
          if (!m.ready)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr(context, 'modeComingSoon'),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 12),
          for (final g in widget.pack)
            Card(
              child: ListTile(
                leading: Text(m.emoji,
                    style: const TextStyle(fontSize: 22)),
                title: Text(g.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.openGuide(context, g.id),
              ),
            ),
        ],
      ),
    );
  }
}
