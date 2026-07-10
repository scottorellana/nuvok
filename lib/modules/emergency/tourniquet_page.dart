// UI del timer de torniquete: hora exacta, tiempo transcurrido GRANDE con
// color por severidad, y compartir al mesh para que el grupo (y el médico
// que reciba al paciente) tengan la hora.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import '../../core/nuvok_library.dart';
import '../mesh/mesh_channel.dart';
import '../mesh/mesh_service.dart';
import 'tourniquet.dart';

class TourniquetPage extends StatefulWidget {
  const TourniquetPage({super.key, this.storeOverride});

  /// Para tests: inyecta un store con directorio temporal.
  final TourniquetStore? storeOverride;

  @override
  State<TourniquetPage> createState() => _TourniquetPageState();
}

class _TourniquetPageState extends State<TourniquetPage> {
  late final TourniquetStore _store = widget.storeOverride ??
      TourniquetStore('${NuvokLibrary.instance.root.path}/emergency');
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Repinta cada segundo: el tiempo transcurrido ES la interfaz.
    _tick = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _startNew() async {
    final ctrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'tqWhere')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: tr(ctx, 'tqWhereHint')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr(ctx, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(tr(ctx, 'tqStart')),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    setState(() => _store.start(label: label));
  }

  Color _color(TourniquetSeverity s) => switch (s) {
        TourniquetSeverity.ok => Colors.green,
        TourniquetSeverity.warning => Colors.orange,
        TourniquetSeverity.critical => Colors.red,
      };

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text('🩸 ${tr(context, 'tqTitle')}')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        onPressed: _startNew,
        icon: const Icon(Icons.add_alarm),
        label: Text(tr(context, 'tqApplied')),
      ),
      body: _store.active.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr(context, 'tqEmpty'),
                    textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final t in _store.active)
                  Card(
                    color: _color(t.severityAt(now)).withValues(alpha: 0.14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.label,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            _fmt(t.elapsedAt(now)),
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: _color(t.severityAt(now)),
                            ),
                          ),
                          Text(switch (t.severityAt(now)) {
                            TourniquetSeverity.ok => tr(context, 'tqOkHint'),
                            TourniquetSeverity.warning =>
                              tr(context, 'tqWarnHint'),
                            TourniquetSeverity.critical =>
                              tr(context, 'tqCritHint'),
                          }),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  await MeshService.instance.sendChat(
                                      MeshChannel.emergency, t.meshNote());
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                tr(context, 'tqShared'))));
                                  }
                                },
                                icon: const Icon(Icons.podcasts, size: 18),
                                label: Text(tr(context, 'tqShare')),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _store.remove(t.id)),
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(tr(context, 'tqResolve')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
