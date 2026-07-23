import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';

// La calidad de la IA depende de que aterrice en la guía CORRECTA. La gente
// no escribe términos clínicos: escribe frases de pánico. Estos casos fijan
// que la búsqueda las mapee bien (por síntoma en lenguaje llano).
void main() {
  late List<EmergencyGuide> es;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    es = await EmergencyGuides.load('es');
  });

  String top(String q) => EmergencyGuides.search(es, q).first.id;

  group('frases realistas en español → guía correcta', () {
    test('paro / no respira, dicho de varias formas', () {
      expect(top('mi papá se desplomó y no responde ni respira'), 'rcp_adulto');
      expect(top('no despierta, está tirado y no reacciona'), 'rcp_adulto');
    });

    test('atragantamiento con sinónimos llanos', () {
      expect(top('se está poniendo morado, se atoró con la comida'),
          'atragantamiento');
      expect(top('mi hijo se ahoga, no puede respirar'), 'atragantamiento');
    });

    test('hemorragia por violencia (sin decir "hemorragia")', () {
      expect(top('le dispararon en la pierna y sangra un montón'),
          'hemorragia_severa');
      expect(top('lo apuñalaron, no para de salir sangre'),
          'hemorragia_severa');
    });

    test('fractura descrita como caída', () {
      expect(top('se cayó de la moto y le duele mucho el brazo, creo que se '
          'lo rompió'), 'fracturas_inmovilizacion');
    });

    test('infarto / ACV en lenguaje llano', () {
      expect(top('le agarró un dolor fuerte en el pecho y el brazo izquierdo'),
          'infarto_acv');
      expect(top('se le torció la cara y habla raro de repente'),
          'infarto_acv');
    });
  });

  group('no rompe los casos simples existentes', () {
    test('palabras clínicas directas siguen funcionando', () {
      expect(top('no respira'), 'rcp_adulto');
      expect(top('sangrado'), 'hemorragia_severa');
      expect(top('se ahoga'), 'atragantamiento');
    });
  });
}
