import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/model_catalog.dart';
import 'package:nuvok/modules/depot/kiwix_catalog.dart';

/// Candado legal: Nuvok se vende, así que NINGÚN modelo que la app ofrezca
/// puede tener licencia de uso no comercial.
///
/// Esto no es teórico: el catálogo incluía Qwen 2.5 3B bajo la "Qwen Research
/// License", que dice literalmente "ÚNICAMENTE PARA FINES NO COMERCIALES", y
/// era el modelo de escritorio por defecto. Se detectó auditando licencias.
void main() {
  group('la cadena automática de modelos es apta para uso comercial', () {
    test('cada modelo declara su licencia', () {
      for (final m in ModelCatalog.all) {
        expect(m.license.trim(), isNotEmpty,
            reason: '${m.id} sin licencia declarada: no se puede auditar');
      }
    });

    test('ninguno tiene licencia de uso NO comercial', () {
      for (final m in ModelCatalog.all) {
        expect(ModelLicense.allowsCommercial(m.license), isTrue,
            reason: '${m.id} usa "${m.license}", que prohíbe vender la app');
      }
    });

    test('la cadena que se descarga sola es 100% permisiva', () {
      // Los modelos que Nuvok elige automáticamente no deben arrastrar
      // obligaciones extra al usuario (avisos, políticas de uso). Si algún
      // día se añade uno con condiciones, que sea una decisión consciente.
      for (final m in ModelCatalog.all) {
        expect(m.license, 'apache-2.0',
            reason: '${m.id}: la cadena automática debe ser Apache 2.0');
      }
    });
  });

  group('el catálogo de Depósito informa la licencia al usuario', () {
    test('cada modelo descargable declara su licencia', () {
      for (final m in curatedModels) {
        expect(m.license.trim(), isNotEmpty, reason: '${m.name} sin licencia');
      }
    });

    test('ninguno prohíbe el uso comercial', () {
      for (final m in curatedModels) {
        expect(ModelLicense.allowsCommercial(m.license), isTrue,
            reason: '${m.name} usa "${m.license}" (no comercial)');
      }
    });
  });

  group('clasificación de licencias', () {
    test('reconoce las que prohíben vender', () {
      expect(ModelLicense.allowsCommercial('qwen-research'), isFalse);
      expect(ModelLicense.allowsCommercial('cc-by-nc-4.0'), isFalse);
      expect(ModelLicense.allowsCommercial('non-commercial'), isFalse);
    });

    test('acepta las permisivas y las comerciales con condiciones', () {
      expect(ModelLicense.allowsCommercial('apache-2.0'), isTrue);
      expect(ModelLicense.allowsCommercial('mit'), isTrue);
      expect(ModelLicense.allowsCommercial('gemma'), isTrue);
      expect(ModelLicense.allowsCommercial('llama3.2'), isTrue);
    });

    test('sabe cuáles obligan a mostrar avisos extra', () {
      expect(ModelLicense.requiresNotice('gemma'), isTrue,
          reason: 'los Gemma Terms obligan a trasladar los términos');
      expect(ModelLicense.requiresNotice('llama3.2'), isTrue,
          reason: 'Llama exige mostrar "Built with Llama"');
      expect(ModelLicense.requiresNotice('apache-2.0'), isFalse);
    });
  });
}
