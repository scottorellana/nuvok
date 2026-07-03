// "Emergencia": big-button access to the bundled life-saving guides, with
// symptom search ("no respira" → RCP) and a large-type reader. Works with
// zero downloads and zero internet — this tab is why the product exists.
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:markdown/markdown.dart' as md;

import 'emergency_guides.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  String _lang = 'es';
  List<EmergencyGuide> _all = [];
  List<EmergencyGuide> _shown = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

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
    if (id.contains('hipotermia') || id.contains('calor') ||
        id.contains('heat') || id.contains('hypo')) {
      return Icons.thermostat;
    }
    if (id.contains('trauma') || id.contains('cabeza') ||
        id.contains('head')) {
      return Icons.psychology_alt;
    }
    if (id.contains('shock')) return Icons.warning;
    return Icons.healing;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guías de Emergencia'),
        actions: [
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _lang == 'es'
                              ? 'Estas guías no sustituyen atención médica '
                                  'profesional.'
                              : 'These guides do not replace professional '
                                  'medical care.',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
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
                                  ? Colors.red.shade900
                                      .withValues(alpha: 0.35)
                                  : null,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          _GuideReader(guide: g)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(_iconFor(g.id),
                                          size: 34,
                                          color: critical
                                              ? Colors.red.shade200
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
}

class _GuideReader extends StatelessWidget {
  const _GuideReader({required this.guide});
  final EmergencyGuide guide;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(guide.title)),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: HtmlWidget(
              md.markdownToHtml(guide.body,
                  extensionSet: md.ExtensionSet.gitHubFlavored),
              textStyle: const TextStyle(fontSize: 17, height: 1.45),
            ),
          ),
        ),
      ),
    );
  }
}
