import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/depot/map_catalog.dart';

// El catálogo debe cargar un mundo razonable y las regiones grandes deben
// venir con maxZoom para que no pesen de más.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('carga un catálogo mundial con muchos países agrupados', () async {
    final regions = await MapCatalog.load();
    expect(regions.length, greaterThan(40));
    // Cubre varios continentes.
    final groups = regions.map((r) => r.group).toSet();
    expect(groups, containsAll(<String>{
      'Norteamérica', 'Sudamérica', 'Europa', 'África', 'Asia', 'Oceanía',
    }));
    // Todas las regiones de extracción traen bbox válido (4 números).
    for (final r in regions) {
      if (r.url != null) continue;
      expect(r.bbox, isNotNull, reason: '${r.id} sin bbox ni url');
      final parts = r.bbox!.split(',');
      expect(parts.length, 4, reason: '${r.id} bbox inválido');
      expect(parts.every((p) => double.tryParse(p) != null), isTrue);
    }
  });

  test('los países grandes limitan el zoom', () async {
    final regions = await MapCatalog.load();
    MapRegion byId(String id) => regions.firstWhere((r) => r.id == id);
    // Gigantes: zoom reducido para que bajen y pesen menos.
    expect(byId('usa').maxZoom, isNotNull);
    expect(byId('brasil').maxZoom, lessThanOrEqualTo(12));
    expect(byId('china').maxZoom, isNotNull);
    // Países chicos conservan detalle de calle (sin cap).
    expect(byId('belize').maxZoom, isNull);
    expect(byId('el-salvador').maxZoom, isNull);
  });
}
