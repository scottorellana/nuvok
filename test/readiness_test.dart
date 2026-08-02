import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/prep/readiness.dart';

/// Descubrir durante el apagón que nunca descargaste el modelo es descubrirlo
/// tarde. Esto decide qué se le dice al usuario ANTES.
void main() {
  ReadinessReport report({
    int aiModels = 1,
    int offlineMaps = 1,
    int libraryFiles = 1,
    bool meshIdentity = true,
    bool meshRadioAvailable = true,
    int batteryLevel = 90,
  }) =>
      assessReadiness(
        aiModels: aiModels,
        offlineMaps: offlineMaps,
        libraryFiles: libraryFiles,
        meshIdentity: meshIdentity,
        meshRadioAvailable: meshRadioAvailable,
        batteryLevel: batteryLevel,
      );

  test('con todo instalado, listo', () {
    final r = report();
    expect(r.level, ReadinessLevel.ready);
    expect(r.score, 100);
    expect(r.missing, isEmpty);
  });

  test('sin malla NO está listo, por mucho que tenga lo demás', () {
    final r = report(meshRadioAvailable: false);
    expect(r.level, ReadinessLevel.notReady,
        reason: 'la malla es lo único sin sustituto: sin ella estás solo');
    expect(r.missing.single.area, ReadinessArea.mesh);
  });

  test('sin identidad tampoco: nadie te puede encontrar', () {
    expect(report(meshIdentity: false).level, ReadinessLevel.notReady);
  });

  test('sin IA queda a medias, no inservible', () {
    final r = report(aiModels: 0);
    expect(r.level, ReadinessLevel.partial,
        reason: 'las guías empaquetadas siguen funcionando sin modelo');
    expect(r.missing.single.area, ReadinessArea.ai);
  });

  test('la batería baja se avisa', () {
    expect(report(batteryLevel: 15).missing.single.area, ReadinessArea.battery);
    expect(report(batteryLevel: 39).level, ReadinessLevel.partial);
    expect(report(batteryLevel: 40).level, ReadinessLevel.ready);
  });

  test('batería desconocida no se castiga', () {
    // -1 = no se pudo leer. Asustar con un dato que falta es peor que callar.
    expect(report(batteryLevel: -1).level, ReadinessLevel.ready);
  });

  test('las guías empaquetadas no son un ítem', () {
    // Un indicador que siempre dice "sí" no informa de nada.
    final areas = report().items.map((i) => i.area).toSet();
    expect(areas.length, report().items.length, reason: 'áreas duplicadas');
    expect(areas, isNot(contains(null)));
    expect(report().items, hasLength(5));
  });

  test('el marcador refleja cuánto falta, no solo si falta algo', () {
    final vacio = report(
        aiModels: 0,
        offlineMaps: 0,
        libraryFiles: 0,
        meshRadioAvailable: false,
        batteryLevel: 5);
    expect(vacio.score, 0);
    expect(vacio.level, ReadinessLevel.notReady);
    expect(report(aiModels: 0, offlineMaps: 0).score, 60);
  });
}
