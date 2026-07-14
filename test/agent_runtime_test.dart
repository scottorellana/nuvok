import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/agent_runtime.dart';
import 'package:nuvok/modules/ai/agents/model_catalog.dart';

void main() {
  final big = ModelCatalog.byId('general-1.7b')!;

  test('resuelve READY cuando el modelo está instalado y cabe', () {
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {big.fileName},
      freeRamBytes: 6000000000,
    );
    expect(s.state, AgentInstallState.ready);
    expect(s.effectiveModel.id, big.id);
    expect(s.usingLiteFallback, isFalse);
  });

  test('resuelve NEEDS_DOWNLOAD cuando no hay ningún modelo usable', () {
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: const {},
      freeRamBytes: 6000000000,
    );
    expect(s.state, AgentInstallState.needsDownload);
  });

  test('sin el modelo principal pero con el ligero instalado, corre en el '
      'ligero (funciona out-of-the-box)', () {
    final lite = ModelCatalog.byId(big.liteFallbackId!)!;
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {lite.fileName}, // solo el 0.5b presente
      freeRamBytes: 6000000000,
    );
    expect(s.state, AgentInstallState.ready);
    expect(s.effectiveModel.id, lite.id);
    expect(s.usingLiteFallback, isTrue);
  });

  test('con RAM insuficiente y modelo instalado, cae al fallback ligero', () {
    final lite = ModelCatalog.byId(big.liteFallbackId!)!;
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {big.fileName, lite.fileName},
      freeRamBytes: 1000000000, // no cabe 1.7B con el guard del 80%
    );
    expect(s.state, AgentInstallState.ready);
    expect(s.effectiveModel.id, lite.id, reason: 'debe caer al ligero');
    expect(s.usingLiteFallback, isTrue);
  });

  test('RAM insuficiente y sin fallback instalado → needsLite', () {
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {big.fileName}, // el lite no está
      freeRamBytes: 1000000000,
    );
    expect(s.state, AgentInstallState.needsLite);
  });

  test('freeRam desconocida (null) asume que cabe', () {
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {big.fileName},
      freeRamBytes: null,
    );
    expect(s.state, AgentInstallState.ready);
    expect(s.usingLiteFallback, isFalse);
  });

  test('detecta señales de crisis en varios idiomas', () {
    expect(AgentRuntime.looksLikeCrisis('quiero suicidarme'), isTrue);
    expect(AgentRuntime.looksLikeCrisis('I want to kill myself'), isTrue);
    expect(AgentRuntime.looksLikeCrisis('¿cómo purifico agua?'), isFalse);
  });
}
