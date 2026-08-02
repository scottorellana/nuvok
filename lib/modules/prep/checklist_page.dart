// Family Preparedness Checklist UI — a guided survival prep tracker.
// Shows progress per category, a circular progress indicator, and
// actionable items that persist in the portable library.
//
// Perishable items display their expiry/rotation date with color coding:
// green (fresh), amber (near expiry ≤30d), red (expired). A summary card
// at the top surfaces items needing attention.
import 'package:flutter/material.dart';

import 'checklist.dart';
import '../../core/shell_nav.dart';
import 'readiness.dart';
import 'readiness_card.dart';
import '../../core/locale_service.dart';

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  /// Lleva al usuario a donde puede resolver lo que le falta. Un diagnóstico
  /// que solo da malas noticias y ninguna salida es peor que no darlo: quien
  /// lee "sin mapas no sabrás dónde estás" necesita el botón, no el susto.
  void _openFor(BuildContext context, ReadinessArea area) {
    switch (area) {
      case ReadinessArea.ai:
        ShellNav.goDepot(tab: ShellNav.depotTabModels);
      case ReadinessArea.maps:
        ShellNav.goDepot(tab: ShellNav.depotTabMaps);
      case ReadinessArea.library:
        ShellNav.goDepot(tab: ShellNav.depotTabLibrary);
      case ReadinessArea.mesh:
        // Comunicación: ahí se ve por qué la radio no está viva (Bluetooth
        // apagado, permiso denegado) y se arregla.
        ShellNav.go(ShellNav.comms);
      case ReadinessArea.location:
        // Comunicación: es donde se enciende el compartir posición y donde el
        // sistema acaba pidiendo el permiso de ubicación.
        ShellNav.go(ShellNav.comms);
      case ReadinessArea.battery:
        ShellNav.go(ShellNav.tools);
    }
  }

  final _progress = ChecklistProgress.instance;

  @override
  Widget build(BuildContext context) {
    final done = _progress.done;
    final pct = _progress.percentComplete();
    final expired = _progress.expiredItems();
    final expiring = _progress.expiringItems(withinDays: 30);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'familyPrep')),
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
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 8,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
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
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_progress.completedCount()} de '
                          '${_progress.totalCount()} completados',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          // El estado del EQUIPO, junto al de la despensa: de nada sirve tener
          // agua para tres días si el día del apagón descubres que nunca
          // descargaste el modelo ni los mapas de tu ciudad.
          ReadinessCard(onFix: (area) => _openFor(context, area)),

          // Expiry alerts
          if (expired.isNotEmpty || expiring.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (expired.isNotEmpty)
              _ExpiryAlertCard(
                items: expired,
                isExpired: true,
                onRotate: (itemId) => _rotateItem(context, itemId),
              ),
            if (expiring.isNotEmpty)
              _ExpiryAlertCard(
                items: expiring,
                isExpired: false,
                onRotate: (itemId) => _rotateItem(context, itemId),
              ),
          ],

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
              onSetExpiry: (itemId) => _pickExpiryDate(context, itemId),
            ),
          const SizedBox(height: 24),
          // Disclaimer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Esta lista está basada en recomendaciones de FEMA y la Cruz '
              'Roja. Adapta las cantidades al tamaño de tu familia y a los '
              'riesgos de tu zona.',
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _rotateItem(BuildContext context, String itemId) {
    setState(() {
      final item = checklistItems.where((i) => i.id == itemId).firstOrNull;
      if (item != null) {
        _progress.setExpiry(
            itemId, ChecklistProgress.suggestedExpiryForItem(item));
      }
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fecha de vencimiento actualizada ✅'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickExpiryDate(BuildContext context, String itemId) async {
    final item = checklistItems.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;

    final current = _progress.getExpiry(itemId);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? ChecklistProgress.suggestedExpiryForItem(item),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Fecha de vencimiento / rotación',
    );
    if (picked != null) {
      setState(() => _progress.setExpiry(itemId, picked));
    }
  }
}

/// Alert card showing expired or near-expiry items.
class _ExpiryAlertCard extends StatelessWidget {
  const _ExpiryAlertCard({
    required this.items,
    required this.isExpired,
    required this.onRotate,
  });

  final List<ExpiringItem> items;
  final bool isExpired;
  final void Function(String itemId) onRotate;

  @override
  Widget build(BuildContext context) {
    final color = isExpired ? Colors.red.shade700 : Colors.orange.shade700;
    final icon = isExpired ? Icons.dangerous : Icons.warning;
    final title = isExpired
        ? 'Vencidos (${items.length})'
        : 'Próximos a vencer (${items.length})';

    return Card(
      color: color.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final e in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.item.text('es'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      e.isExpired
                          ? '${e.daysRemaining.abs()}d vencido'
                          : '${e.daysRemaining}d',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.refresh, size: 18, color: color),
                        tooltip: 'Rotar',
                        onPressed: () => onRotate(e.item.id),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
    required this.onSetExpiry,
  });

  final ChecklistCategory category;
  final int completed;
  final int total;
  final Set<String> done;
  final void Function(String itemId) onToggle;
  final void Function(String itemId) onSetExpiry;

  @override
  Widget build(BuildContext context) {
    final progress = ChecklistProgress.instance;
    final items = progress.itemsForCategory(category.id);
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
            _ChecklistTile(
              item: item,
              isDone: done.contains(item.id),
              progress: progress,
              onToggle: () => onToggle(item.id),
              onSetExpiry: () => onSetExpiry(item.id),
            ),
        ],
      ),
    );
  }
}

/// Individual checklist item tile with expiry badge.
class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.item,
    required this.isDone,
    required this.progress,
    required this.onToggle,
    required this.onSetExpiry,
  });

  final ChecklistItem item;
  final bool isDone;
  final ChecklistProgress progress;
  final VoidCallback onToggle;
  final VoidCallback onSetExpiry;

  @override
  Widget build(BuildContext context) {
    final days = progress.daysUntilExpiry(item.id);
    final expired = progress.isExpired(item.id);
    final nearExpiry = progress.isNearExpiry(item.id);

    // Expiry badge color
    Color? badgeColor;
    String? badgeText;
    if (days != null) {
      if (expired) {
        badgeColor = Colors.red;
        badgeText = 'Vencido ${days.abs()}d';
      } else if (nearExpiry) {
        badgeColor = Colors.orange;
        badgeText = '${days}d';
      }
    }

    return ListTile(
      leading: Checkbox(
        value: isDone,
        onChanged: (_) => onToggle(),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.textEs,
              style: TextStyle(
                decoration: isDone ? TextDecoration.lineThrough : null,
                color: isDone ? Theme.of(context).hintColor : null,
              ),
            ),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor!.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor, width: 1),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: item.isPerishable && isDone
          ? Wrap(
              spacing: 8,
              children: [
                if (days != null)
                  Text(
                    expired
                        ? '⚠ Venció hace ${days.abs()} días'
                        : nearExpiry
                            ? 'Rotar en $days días'
                            : 'Vence: ${_formatDate(progress.getExpiry(item.id)!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: expired
                          ? Colors.red.shade300
                          : nearExpiry
                              ? Colors.orange.shade300
                              : Theme.of(context).hintColor,
                    ),
                  )
                else
                  Text(
                    'Perecedero — vencimiento sugerido: '
                    '${item.expiryMonths} meses',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                if (item.isPerishable)
                  Semantics(
                    button: true,
                    label: 'Cambiar fecha de vencimiento',
                    child: InkWell(
                      onTap: onSetExpiry,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: Text(
                          'Cambiar fecha',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : null,
      onTap: onToggle,
      dense: true,
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
