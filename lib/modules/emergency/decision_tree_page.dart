// Navegador del árbol de decisión: UNA pregunta por pantalla, botones
// gigantes legibles en pánico, y al llegar a la hoja abre la guía exacta.
import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import 'decision_tree.dart';

class DecisionTreePage extends StatefulWidget {
  const DecisionTreePage({super.key, required this.openGuide});

  /// La página no conoce el lector de guías: quien la crea decide cómo abrir
  /// una guía por id (emergency_page pasa su propio lector).
  final void Function(BuildContext context, String guideId) openGuide;

  @override
  State<DecisionTreePage> createState() => _DecisionTreePageState();
}

class _DecisionTreePageState extends State<DecisionTreePage> {
  final _path = <String>['root'];

  DtNode get _node => decisionTree[_path.last]!;

  void _choose(DtOption o) {
    if (o.guideId != null) {
      widget.openGuide(context, o.guideId!);
      return;
    }
    setState(() => _path.add(o.next!));
  }

  @override
  Widget build(BuildContext context) {
    final node = _node;
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      appBar: AppBar(
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        title: Text(tr(context, 'dtTitle')),
        leading: _path.length > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _path.removeLast()),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                tr(context, node.questionKey),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    for (final o in node.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red.shade900,
                            minimumSize: const Size.fromHeight(76),
                            textStyle: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                          onPressed: () => _choose(o),
                          child: Text(tr(context, o.labelKey),
                              textAlign: TextAlign.center),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
