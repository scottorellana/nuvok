// Family Preparedness Checklist UI — a guided survival prep tracker.
// Shows progress per category, a circular progress indicator, and
// actionable items that persist in the portable library.
import 'package:flutter/material.dart';

import 'checklist.dart';

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  final _progress = ChecklistProgress.instance;

  @override
  Widget build(BuildContext context) {
    final done = _progress.done;
    final pct = _progress.percentComplete();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparación Familiar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_progress.completedCount()}/${_progress.totalCount()}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overall progress card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  SizedBox(
                    width: 80, height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 8,
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        Text(
                          '${(pct * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pct >= 1.0
                              ? '¡Estás preparado! 🎉'
                              : pct >= 0.5
                                  ? 'Vas por buen camino 💪'
                                  : 'Empieza tu preparación 🏠',
                          style:
                              Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_progress.completedCount()} de '
                          '${_progress.totalCount()} completados',
                          style: TextStyle(
                            color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Categories
          for (final cat in categories)
            _CategoryCard(
              category: cat,
              completed: _progress.completedInCategory(cat.id),
              total: _progress.totalInCategory(cat.id),
              done: done,
              onToggle: (itemId) => setState(() {
                _progress.toggle(itemId);
              }),
            ),
          const SizedBox(height: 24),
          // Disclaimer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Esta lista está basada en recomendaciones de FEMA y la Cruz '
              'Roja. Adapta las cantidades al tamaño de tu familia y a los '
              'riesgos de tu zona.',
              style: TextStyle(
                fontSize: 12, color: Theme.of(context).hintColor),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.completed,
    required this.total,
    required this.done,
    required this.onToggle,
  });
  final ChecklistCategory category;
  final int completed;
  final int total;
  final Set<String> done;
  final void Function(String itemId) onToggle;

  @override
  Widget build(BuildContext context) {
    final items = ChecklistProgress.instance.itemsForCategory(category.id);
    final catPct = total > 0 ? completed / total : 0.0;
    final allDone = completed == total;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Text(category.icon, style: const TextStyle(fontSize: 28)),
        title: Text(
          category.name('es'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: allDone ? Colors.green : null,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: catPct,
                minHeight: 6,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$completed/$total',
              style: TextStyle(
                fontSize: 12,
                color: allDone ? Colors.green : Theme.of(context).hintColor,
                fontWeight: allDone ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
        children: [
          for (final item in items)
            CheckboxListTile(
              value: done.contains(item.id),
              onChanged: (_) => onToggle(item.id),
              title: Text(
                item.textEs,
                style: TextStyle(
                  decoration: done.contains(item.id)
                      ? TextDecoration.lineThrough
                      : null,
                  color: done.contains(item.id)
                      ? Theme.of(context).hintColor
                      : null,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
        ],
      ),
    );
  }
}
