// The single downloadable-model catalog. One .gguf runs on iOS, Android and
// macOS alike — llama.cpp is embedded identically via FFI and the per-device
// adaptation (Metal/NEON, context size) happens at runtime in AiEngine. So
// there are no per-platform model variants: this catalog is shared.

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
  /// binaries are published (see the plan's release task) — the download
  /// wiring passes null while it is the marker so verification stays off.
  final String sha256;

  /// Smaller model to use when this one does not fit free RAM. null = none.
  final String? liteFallbackId;
}

class ModelCatalog {
  static const String _base = 'https://nuvok.org/models';

  static const List<ModelEntry> all = [
    ModelEntry(
      id: 'general-1.7b',
      fileName: 'qwen3-1.7b-instruct-q4_k_m.gguf',
      url: '$_base/qwen3-1.7b-instruct-q4_k_m.gguf',
      sizeBytes: 1120000000,
      sha256: 'TO_FILL_ON_UPLOAD',
      liteFallbackId: 'general-0.5b',
    ),
    ModelEntry(
      id: 'general-0.5b',
      fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      url: '$_base/qwen2.5-0.5b-instruct-q4_k_m.gguf',
      sizeBytes: 492000000,
      sha256: 'TO_FILL_ON_UPLOAD',
    ),
    ModelEntry(
      id: 'translate-0.6b',
      fileName: 'qwen3-0.6b-instruct-q4_k_m.gguf',
      url: '$_base/qwen3-0.6b-instruct-q4_k_m.gguf',
      sizeBytes: 520000000,
      sha256: 'TO_FILL_ON_UPLOAD',
      liteFallbackId: 'general-0.5b',
    ),
  ];

  static ModelEntry? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
