// Árbol de decisión estilo despachador del 911: una pregunta por pantalla,
// botones gigantes, determinista — CERO IA. Convierte pánico en el
// procedimiento exacto, igual que un operador de emergencias por teléfono.
//
// El motor es puro (testeable); las hojas apuntan a ids de guías reales y un
// test de integridad verifica que existan en ambos idiomas.

/// Una opción de respuesta: etiqueta (clave i18n) y a dónde lleva.
class DtOption {
  const DtOption(this.labelKey, {this.next, this.guideId})
      : assert(next != null || guideId != null);
  final String labelKey;
  final String? next; // id de otro nodo
  final String? guideId; // hoja: abre esta guía
}

class DtNode {
  const DtNode({required this.id, required this.questionKey, required this.options});
  final String id;
  final String questionKey;
  final List<DtOption> options;
}

/// El árbol curado. Empezar SIEMPRE por 'root'.
const Map<String, DtNode> decisionTree = {
  'root': DtNode(
    id: 'root',
    questionKey: 'dtResponds',
    options: [
      DtOption('dtNo', next: 'breathing'),
      DtOption('dtYes', next: 'what'),
    ],
  ),
  'breathing': DtNode(
    id: 'breathing',
    questionKey: 'dtBreathing',
    options: [
      DtOption('dtNo', guideId: 'rcp_adulto'),
      DtOption('dtYes', next: 'impact'),
    ],
  ),
  'impact': DtNode(
    id: 'impact',
    questionKey: 'dtHadImpact',
    options: [
      DtOption('dtYes', guideId: 'trauma_cabeza_columna'),
      DtOption('dtNo', guideId: 'shock'),
    ],
  ),
  'what': DtNode(
    id: 'what',
    questionKey: 'dtWhatHappens',
    options: [
      DtOption('dtChoking', guideId: 'atragantamiento'),
      DtOption('dtBleeding', guideId: 'hemorragia_severa'),
      DtOption('dtBurn', guideId: 'quemaduras'),
      DtOption('dtChest', guideId: 'infarto_acv'),
      DtOption('dtSeizure', guideId: 'convulsiones'),
      DtOption('dtPoison', guideId: 'intoxicaciones'),
    ],
  ),
};

/// Todas las hojas del árbol (para el test de integridad).
Iterable<String> decisionTreeLeafGuideIds() sync* {
  for (final node in decisionTree.values) {
    for (final o in node.options) {
      if (o.guideId != null) yield o.guideId!;
    }
  }
}

/// Todos los nodos alcanzables desde root deben existir.
bool decisionTreeIsClosed() {
  for (final node in decisionTree.values) {
    for (final o in node.options) {
      if (o.next != null && !decisionTree.containsKey(o.next)) return false;
    }
  }
  return decisionTree.containsKey('root');
}
