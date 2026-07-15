import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/agent_runtime.dart';
import 'package:nuvok/modules/ai/agents/model_catalog.dart';

void main() {
  final big = ModelCatalog.byId('general-3b')!; // 1.93 GB
  final mid = ModelCatalog.byId('general-1.5b')!; // 1.12 GB
  final small = ModelCatalog.byId('general-0.5b')!; // 492 MB

  test('resuelve READY cuando el modelo grande está instalado y cabe', () {
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {big.fileName},
      freeRamBytes: 6000000000, // holgado
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

  test('sin el modelo principal pero con uno menor instalado, corre en el '
      'menor (funciona out-of-the-box)', () {
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {small.fileName}, // solo el 0.5b presente
      freeRamBytes: 6000000000,
    );
    expect(s.state, AgentInstallState.ready);
    expect(s.effectiveModel.id, small.id);
    expect(s.usingLiteFallback, isTrue);
  });

  test('camina la cadena: 3B no cabe pero 1.5B sí → corre en 1.5B', () {
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {big.fileName, mid.fileName},
      // 0.8 * 2GB = 1.6GB: no cabe el 3B (1.93), sí el 1.5B (1.12).
      freeRamBytes: 2000000000,
    );
    expect(s.state, AgentInstallState.ready);
    expect(s.effectiveModel.id, mid.id, reason: 'debe caer al 1.5B');
    expect(s.usingLiteFallback, isTrue);
  });

  test('RAM insuficiente y sin modelo menor instalado → needsLite', () {
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {big.fileName}, // ningún fallback presente
      freeRamBytes: 1000000000, // no cabe el 3B
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
