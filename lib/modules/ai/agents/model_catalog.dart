// The downloadable-model catalog. One .gguf runs on iOS, Android and macOS
// alike — llama.cpp is embedded identically via FFI and the per-device
// adaptation (Metal/NEON, context size) happens at runtime in AiEngine.
//
// Capacity, though, DOES vary by device: a 0.5B model is incoherent as a
// specialist (verified), so the "general" model resolves to a bigger model on
// desktop (more RAM) than on phones, each with a chain of lighter fallbacks
// down to what any device can run.

class ModelEntry {
  const ModelEntry({
    required this.id,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    this.liteFallbackId,
  });

  final String id;
  final String fileName;
  final String url;
  final int sizeBytes;

  /// Expected hash; verified before install. 'TO_FILL_ON_UPLOAD' until the
  /// binaries are published — the download wiring passes null while it is the
  /// marker so verification stays off for dev/self-hosted builds.
  final String sha256;

  /// Next-smaller model to try when this one is not installed or does not fit
  /// RAM. Forms a chain (desktop-3b → 1.5b → 1b → 0.5b) that AgentRuntime
  /// walks until it finds one that is both installed and fits.
  final String? liteFallbackId;
}

/// Logical model classes an agent can ask for. The concrete [ModelEntry] is
/// resolved per device (see [ModelCatalog.resolveClass]).
enum ModelClass { general }

class ModelCatalog {
  static const String _base = 'https://nuvok.org/models';

  static const List<ModelEntry> all = [
    // Desktop tier: a 3B is a genuinely solid specialist and a 18GB Mac runs
    // it comfortably.
    ModelEntry(
      id: 'general-3b',
      fileName: 'qwen2.5-3b-instruct-q4_k_m.gguf',
      url: '$_base/qwen2.5-3b-instruct-q4_k_m.gguf',
      sizeBytes: 1930000000,
      sha256: 'TO_FILL_ON_UPLOAD',
      liteFallbackId: 'general-1.5b',
    ),
    // Phone tier: 1.5B is coherent and fits mid-range phones.
    ModelEntry(
      id: 'general-1.5b',
      fileName: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      url: '$_base/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      sizeBytes: 1120000000,
      sha256: 'TO_FILL_ON_UPLOAD',
      liteFallbackId: 'general-1b',
    ),
    // 1B fallback: verified coherent as a specialist; last resort before 0.5B.
    ModelEntry(
      id: 'general-1b',
      fileName: 'google_gemma-3-1b-it-Q4_K_M.gguf',
      url: '$_base/google_gemma-3-1b-it-Q4_K_M.gguf',
      sizeBytes: 806000000,
      sha256: 'TO_FILL_ON_UPLOAD',
      liteFallbackId: 'general-0.5b',
    ),
    // 0.5B: only as an absolute last resort (incoherent as a specialist).
    ModelEntry(
      id: 'general-0.5b',
      fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      url: '$_base/qwen2.5-0.5b-instruct-q4_k_m.gguf',
      sizeBytes: 492000000,
      sha256: 'TO_FILL_ON_UPLOAD',
    ),
  ];

  static ModelEntry? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Resolves a logical [ModelClass] to the best concrete model for the
  /// device. Desktop gets the big model; phones start one tier down. The
  /// caller (AgentRuntime) then walks the fallback chain by what is installed.
  static ModelEntry resolveClass(ModelClass cls, {required bool isDesktop}) {
    switch (cls) {
      case ModelClass.general:
        return byId(isDesktop ? 'general-3b' : 'general-1.5b')!;
    }
  }

  /// The fallback chain starting at [entry] (inclusive), following
  /// liteFallbackId to the end. Used to pick the best installed model.
  static List<ModelEntry> chainFrom(ModelEntry entry) {
    final chain = <ModelEntry>[];
    ModelEntry? cur = entry;
    final seen = <String>{};
    while (cur != null && seen.add(cur.id)) {
      chain.add(cur);
      cur = cur.liteFallbackId == null ? null : byId(cur.liteFallbackId!);
    }
    return chain;
  }
}
