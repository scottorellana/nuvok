import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/emergency_retriever.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';

/// El "modo de supervivencia" (bosque, mar, ciudad…) dice DÓNDE estás, no QUÉ
/// le pasa a la persona que tienes delante. Antes reordenaba los resultados de
/// forma dura: con el modo bosque activo, preguntar "no respira" devolvía
/// primero la guía de incendio forestal — porque el incendio pertenece al
/// modo y la RCP no. El entorno no puede ganarle al triaje clínico.
EmergencyGuide _g(String id, String title, int priority, List<String> modes) =>
    EmergencyGuide(
      id: id,
      lang: 'es',
      title: title,
      keywords: const [],
      priority: priority,
      body: '# $title',
      modes: modes,
    );

void main() {
  // Una guía vital (prioridad 1) que NO pertenece al modo, y una del modo
  // que es mucho menos urgente.
  final rcp = _g('rcp_adulto', 'RCP en adultos', 1, const []);
  final incendio = _g('incendio_forestal', 'Incendio forestal', 4, ['bosque']);
  final agua = _g('bosque_agua', 'Agua en el bosque', 5, ['bosque']);

  group('el modo no puede desplazar a una guía vital', () {
    test('lo vital sigue primero aunque el modo tenga candidatas', () {
      final out = EmergencyRetriever.boostByMode([rcp, incendio, agua], 'bosque');
      expect(out.first.id, 'rcp_adulto',
          reason: 'con "no respira" en modo bosque, la RCP manda: '
              '${out.map((g) => g.id).toList()}');
    });

    test('entre guías de urgencia parecida, el modo SÍ desempata', () {
      final generica = _g('refugio', 'Refugio improvisado', 5, const []);
      final delModo = _g('bosque_refugio', 'Refugio en bosque', 5, ['bosque']);
      final out =
          EmergencyRetriever.boostByMode([generica, delModo], 'bosque');
      expect(out.first.id, 'bosque_refugio',
          reason: 'a igual urgencia, el entorno es la mejor pista');
    });

    test('sin modo activo no se reordena nada', () {
      final orden = [incendio, rcp, agua];
      expect(EmergencyRetriever.boostByMode(orden, null), same(orden));
      expect(EmergencyRetriever.boostByMode(orden, ''), same(orden));
    });

    test('el orden de búsqueda se conserva dentro de cada grupo', () {
      final a = _g('a', 'A', 3, ['mar']);
      final b = _g('b', 'B', 3, ['mar']);
      final out = EmergencyRetriever.boostByMode([a, b], 'mar');
      expect(out.map((g) => g.id), ['a', 'b'],
          reason: 'la relevancia textual del buscador no debe barajarse');
    });
  });
}
