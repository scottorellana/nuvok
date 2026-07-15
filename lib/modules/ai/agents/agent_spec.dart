// A local specialist: identity + expert prompt + sources + declared model.
// Pure, testable data — it never touches the engine or the UI. The UI reads
// these to draw the specialist grid; the runtime reads modelId/grounding to
// wire the engine.
import 'package:flutter/material.dart';

import 'model_catalog.dart';

/// Where the agent draws its evidence from before generating.
enum GroundingMode {
  /// Emergency guides first, then the library (Vera, Norte, Elías).
  guidesFirst,

  /// The whole installed ZIM library, with citations (Sabio, Bruno).
  library,

  /// No retrieval; the prompt is everything (Lía the translator).
  none,
}

class AgentSpec {
  const AgentSpec({
    required this.id,
    required this.nameProper,
    required this.roleByLang,
    required this.avatar,
    required this.accent,
    required this.modelClass,
    required this.grounding,
    required this.temperature,
    required this.systemByLang,
    required this.quickChipKeys,
    this.crisisGuardrails = false,
  });

  final String id;
  final String nameProper; // never translated
  final Map<String, String> roleByLang;
  final IconData avatar;
  final Color accent;
  final ModelClass modelClass; // resolved per-device by ModelCatalog
  final GroundingMode grounding;
  final double temperature;
  final Map<String, String> systemByLang;
  final List<String> quickChipKeys;
  final bool crisisGuardrails;

  /// Localized role: requested language → English → Spanish → id.
  String role(String lang) =>
      roleByLang[lang] ?? roleByLang['en'] ?? roleByLang['es'] ?? id;

  /// System prompt: requested language → English → Spanish → empty.
  String system(String lang) =>
      systemByLang[lang] ?? systemByLang['en'] ?? systemByLang['es'] ?? '';
}
