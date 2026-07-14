// Pure decision logic for a specialist: given which models are installed and
// how much RAM is free, decide whether it is ready to run, needs a download,
// or should fall back to a lighter model. No IO — deterministic and testable.
// The RAM guard matters most on phones: iOS jetsam kills apps that exceed the
// budget, Android OOM-kills, so an oversized model must degrade, not crash.
import 'model_catalog.dart';

enum AgentInstallState {
  ready, // the model (or its fallback) is installed and fits RAM
  needsDownload, // the main model is not installed
  needsLite, // it does not fit RAM and the lite fallback is not installed
}

class AgentStatus {
  const AgentStatus({
    required this.state,
    required this.effectiveModel,
    required this.usingLiteFallback,
  });

  final AgentInstallState state;
  final ModelEntry effectiveModel; // the model that would actually load
  final bool usingLiteFallback;
}

class AgentRuntime {
  /// Fraction of free RAM a model may occupy without risking a memory-pressure
  /// kill (jetsam on iOS, OOM on Android).
  static const double ramSafety = 0.8;

  static bool _fits(ModelEntry m, int? freeRamBytes) =>
      freeRamBytes == null || m.sizeBytes <= freeRamBytes * ramSafety;

  static AgentStatus resolve({
    required ModelEntry model,
    required Set<String> installedFileNames,
    required int? freeRamBytes,
  }) {
    final mainInstalled = installedFileNames.contains(model.fileName);
    final lite = model.liteFallbackId == null
        ? null
        : ModelCatalog.byId(model.liteFallbackId!);
    final liteInstalled =
        lite != null && installedFileNames.contains(lite.fileName);

    if (!mainInstalled) {
      return AgentStatus(
        state: AgentInstallState.needsDownload,
        effectiveModel: model,
        usingLiteFallback: false,
      );
    }
    if (_fits(model, freeRamBytes)) {
      return AgentStatus(
        state: AgentInstallState.ready,
        effectiveModel: model,
        usingLiteFallback: false,
      );
    }
    // Does not fit: try the lighter model.
    if (lite != null && liteInstalled && _fits(lite, freeRamBytes)) {
      return AgentStatus(
        state: AgentInstallState.ready,
        effectiveModel: lite,
        usingLiteFallback: true,
      );
    }
    return AgentStatus(
      state: AgentInstallState.needsLite,
      effectiveModel: lite ?? model,
      usingLiteFallback: lite != null,
    );
  }

  /// Minimal multilingual crisis markers for the psychologist's guardrail.
  /// Substring match, lowercased — err toward showing the SOS affordance.
  static const List<String> _crisisMarkers = [
    'suicid', 'matarme', 'me quiero morir', 'quitarme la vida',
    'kill myself', 'end my life', 'want to die',
    'me tuer', 'suicídio', '自杀', '死にたい',
  ];

  static bool looksLikeCrisis(String text) {
    final low = text.toLowerCase();
    return _crisisMarkers.any(low.contains);
  }
}
