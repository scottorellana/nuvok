// The downloadable-model catalog. One .gguf runs on iOS, Android and macOS
// alike — llama.cpp is embedded identically via FFI and the per-device
// adaptation (Metal/NEON, context size) happens at runtime in AiEngine.
//
// Capacity, though, DOES vary by device: a 0.5B model is incoherent as a
// specialist (verified), so the "general" model resolves to a bigger model on
// desktop (more RAM) than on phones, each with a chain of lighter fallbacks
// down to what any device can run.


/// Clasificación de licencias de modelos. Nuvok se VENDE, así que una
/// licencia de investigación (no comercial) es un bloqueo, no un detalle.
class ModelLicense {
  ModelLicense._();

  /// Licencias que prohíben el uso comercial. Nada de esto puede entrar.
  static const _nonCommercial = {
    'qwen-research', 'cc-by-nc-4.0', 'cc-by-nc-sa-4.0', 'non-commercial',
    'research-only',
  };

  /// Permiten vender, PERO obligan a mostrar avisos o trasladar términos.
  static const _withNotice = {'gemma', 'llama3.2', 'llama3.1', 'llama3'};

  static bool allowsCommercial(String license) =>
      !_nonCommercial.contains(license.trim().toLowerCase());

  static bool requiresNotice(String license) =>
      _withNotice.contains(license.trim().toLowerCase());
}

class ModelEntry {
  const ModelEntry({
    required this.id,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    required this.license,
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

  /// Identificador de licencia (el de Hugging Face). Auditable por test:
  /// ninguna entrada puede tener licencia de uso no comercial.
  final String license;

  /// Next-smaller model to try when this one is not installed or does not fit
  /// RAM. Forms a chain (desktop-3b → 1.5b → 1b → 0.5b) that AgentRuntime
  /// walks until it finds one that is both installed and fits.
  final String? liteFallbackId;
}

/// Logical model classes an agent can ask for. The concrete [ModelEntry] is
/// resolved per device (see [ModelCatalog.resolveClass]).
enum ModelClass { general }

class ModelCatalog {
  // Los modelos se sirven desde los repos GGUF oficiales en Hugging Face
  // (CDN global, gratis). SHA-256 = LFS oid publicado por HF, verificado
  // contra descarga real. Si algún día migramos a downloads.nuvok.org (R2),
  // solo cambian estas URLs — fileName y sha256 quedan iguales.
  static const List<ModelEntry> all = [
    // Desktop tier: Gemma 4 E4B — el mejor especialista que cabe en una
    // computadora de 16-18GB. GGUF comunitario (lmstudio): el QAT oficial de
    // Google NO carga en llama.cpp (assert de vocabulario, verificado).
    ModelEntry(
      id: 'general-e4b',
      fileName: 'gemma-4-E4B-it-Q4_K_M.gguf',
      url: 'https://huggingface.co/lmstudio-community/gemma-4-E4B-it-GGUF/'
          'resolve/main/gemma-4-E4B-it-Q4_K_M.gguf',
      sizeBytes: 5335289664,
      sha256:
          '3f72a20a06f626c78e6c475ae07a64c88b2663149c0f6197b56bf7cf1f37585c',
      license: 'apache-2.0',
      liteFallbackId: 'general-e2b',
    ),
    // Phone tier: Gemma 4 E2B — diseñado por Google para dispositivos;
    // respuestas de nivel especialista verificadas vía FFI (pp_llm renderiza
    // su plantilla <|turn> sin thinking). El RAM guard manda a los teléfonos
    // que no lo aguanten a la cadena Qwen de abajo.
    ModelEntry(
      id: 'general-e2b',
      fileName: 'gemma-4-E2B-it-Q4_K_M.gguf',
      url: 'https://huggingface.co/lmstudio-community/gemma-4-E2B-it-GGUF/'
          'resolve/main/gemma-4-E2B-it-Q4_K_M.gguf',
      sizeBytes: 3427877696,
      sha256:
          '6c950d754366dd8b372fd17a40497ba5f130a46d833b4c5bccc9f6bb6382ce1e',
      license: 'apache-2.0',
      liteFallbackId: 'general-e2b-qat',
    ),
    // EL ESCALÓN QUE RESCATA AL TELÉFONO DE 4 GB: el mismo Gemma 4 E2B, pero con pesos
    // entrenados para 4 bits (QAT) y requantizado por Unsloth con un mix que sí
    // toca las tablas de embeddings — que son el 59% del modelo y lo que hace
    // que la cuantización normal no adelgace nada.
    //
    // 2,62 GB frente a 3,43 GB: 0,81 GB menos, y con calidad de 4 bits reales,
    // no de 2. Eso baja el umbral de RAM libre que exige el guardián (tamaño /
    // 0,8) de 4,29 GB a 3,28 GB, que es justo la diferencia entre un teléfono
    // de 4 GB usando el modelo bueno o cayendo a qwen-0.5b.
    //
    // Va DEBAJO del E2B normal para que la cadena siga siendo estrictamente
    // decreciente en tamaño (es una cadena de respaldo: cada peldaño tiene que
    // pedir menos que el anterior) y para que quien ya tenga el E2B descargado
    // lo siga usando en vez de bajarse 2,6 GB otra vez.
    //
    // Verificado antes de ponerlo aquí, porque el QAT oficial de Google no
    // carga (assert de vocabulario): descargado, comprobado el tamaño exacto y
    // el SHA-256, cargado en libppllm a n_ctx 4096, y contrastado contra el
    // Q4_K_M actual en cuatro preguntas médicas (RCP, atragantamiento,
    // torniquete, quemadura). Respuestas equivalentes.
    ModelEntry(
      id: 'general-e2b-qat',
      fileName: 'gemma-4-E2B-it-qat-UD-Q4_K_XL.gguf',
      url: 'https://huggingface.co/unsloth/gemma-4-E2B-it-qat-GGUF/'
          'resolve/main/gemma-4-E2B-it-qat-UD-Q4_K_XL.gguf',
      sizeBytes: 2620370976,
      sha256:
          'e531007218dfab990486a5de7676a6932d6ea8dea233d1f698d7c21cf8a16889',
      license: 'apache-2.0',
      liteFallbackId: 'general-1.5b',
    ),
    // NOTA LEGAL: aquí estaba Qwen 2.5 3B. Se retiró porque su licencia
    // ("Qwen Research License") permite el uso SOLO NO COMERCIAL, y Nuvok se
    // vende. No volver a añadirlo: el test model_licenses_test lo bloquea.
    // Escalón de respaldo: el que acaban usando los teléfonos más modestos, o
    // sea la gente que más necesita que esto funcione.
    //
    // Aquí estaba qwen2.5-1.5b y se cambió por datos, no por moda. Probados
    // los dos sobre libppllm con la plantilla real de cada uno:
    //
    //   "¿Cuánta profundidad deben tener las compresiones de RCP?"
    //     qwen2.5-1.5b → "Las compresiones de Resumen de Contenido (RCP)…
    //                     al menos 3-5 puntos principales" (no sabe qué es RCP)
    //     Qwen3-1.7B   → "aproximadamente 5 cm"  ✓
    //
    //   "Un niño de 3 años se atraganta y no puede toser. ¿Qué hago primero?"
    //     qwen2.5-1.5b → "intenta calmarlo… puedes intentar hacerle toser con
    //                     un bocadillo o un jugo"  ← PELIGROSO: dar comida o
    //                     bebida a quien se atraganta es la contraindicación
    //                     número uno
    //     Qwen3-1.7B   → "Lleva a un médico" (pobre, pero no hace daño)
    //
    // Con las guías inyectadas los dos responden bien, pero el respaldo también
    // contesta preguntas fuera del alcance de las guías, y ahí el viejo hacía
    // daño. Pesa además 10 MB MENOS.
    //
    // Necesita que pp_llm desactive el modo de razonamiento (apply_chatml_no_think):
    // sin eso Qwen3 emite <think> y no llega a responder.
    ModelEntry(
      id: 'general-1.5b',
      fileName: 'Qwen3-1.7B-Q4_K_M.gguf',
      url: 'https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/'
          'resolve/main/Qwen3-1.7B-Q4_K_M.gguf',
      sizeBytes: 1107409472,
      sha256:
          'b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897',
      license: 'apache-2.0',
      liteFallbackId: 'general-0.5b',
    ),
    // NOTA LEGAL: aquí estaba Gemma 3 1B. Se retiró de la cadena AUTOMÁTICA
    // porque los "Gemma Terms of Use" obligan a trasladar sus términos y su
    // política de uso a cada usuario. Sigue disponible en Depósito, donde el
    // usuario lo elige y ve su licencia.
    // 0.5B: only as an absolute last resort (incoherent as a specialist).
    // Mismo archivo que viaja empaquetado en la app (SHA idéntico al del
    // manifest de assets/bundled_library).
    ModelEntry(
      id: 'general-0.5b',
      fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      url: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/'
          'resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
      sizeBytes: 491400032,
      sha256:
          '74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db',
      license: 'apache-2.0',
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
        return byId(isDesktop ? 'general-e4b' : 'general-e2b')!;
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
