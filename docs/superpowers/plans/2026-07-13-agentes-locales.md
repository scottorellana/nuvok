# Especialistas locales de Nuvok — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el chat genérico de `.gguf` por 6 especialistas con identidad, prompt experto por idioma, grounding y modelo declarado, funcionando igual en iOS/Android/macOS.

**Architecture:** Datos puros (`AgentSpec`, `ModelCatalog`) en `lib/modules/ai/agents/`, sin servidor ni dependencias nuevas. El motor FFI existente (`AiEngine`) se reutiliza tal cual; un mismo GGUF corre en las tres plataformas y la adaptación (Metal/NEON, nCtx) ya se resuelve en runtime. La UI de la pestaña Asistente pasa de dropdown+switches a cuadrícula de agentes + chat con cabecera. Se reutilizan `EmergencyRetriever`, `LibraryRetriever`, `DownloadManager` y `AppStrings`.

**Tech Stack:** Flutter/Dart, `crypto` (sha256, ya en pubspec), `path_provider`, FFI a `libppllm`. Tests con `flutter_test`.

**Nota de dependencia externa (no bloquea el código):** los `.gguf` del catálogo deben subirse a `https://nuvok.org/models/` con su sha256. Hasta entonces, los tests de descarga usan un servidor HTTP local (`HttpServer.bind`) y los tests live usan el modelo ya presente en `~/nuvok/models/`. El catálogo real de URLs se rellena en la Task 8.

---

## Estructura de archivos

- Crear `lib/modules/ai/agents/agent_spec.dart` — tipo `AgentSpec` + `GroundingMode`.
- Crear `lib/modules/ai/agents/agent_catalog.dart` — los 6 specs constantes.
- Crear `lib/modules/ai/agents/model_catalog.dart` — `ModelEntry` + lista + lookup.
- Crear `lib/modules/ai/agents/agent_runtime.dart` — resolver modelo/estado/guard RAM de un agente (lógica pura testeable).
- Modificar `lib/modules/depot/download_manager.dart` — verificación sha256 opcional antes del rename.
- Reescribir `lib/modules/ai/ai_page.dart` — cuadrícula + chat con cabecera de agente.
- Modificar `lib/core/locale_service.dart` — claves i18n nuevas (roles, estados, chips).
- Modificar `lib/modules/settings/settings_page.dart` — "modo avanzado: cargar .gguf manual".
- Tests: `test/agent_catalog_test.dart`, `test/model_catalog_test.dart`, `test/agent_runtime_test.dart`, `test/download_sha256_test.dart`, `test/agent_live_test.dart`.

---

## Task 1: `AgentSpec` y `GroundingMode`

**Files:**
- Create: `lib/modules/ai/agents/agent_spec.dart`
- Test: `test/agent_catalog_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/agent_catalog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/agent_spec.dart';

void main() {
  test('AgentSpec expone rol y system prompt por idioma con fallback', () {
    final spec = AgentSpec(
      id: 'test',
      nameProper: 'Tester',
      roleByLang: const {'es': 'Rol', 'en': 'Role'},
      avatar: Icons.person,
      accent: const Color(0xFF000000),
      modelId: 'general-1.7b',
      grounding: GroundingMode.none,
      temperature: 0.7,
      systemByLang: const {'es': 'sys es', 'en': 'sys en'},
      quickChipKeys: const [],
    );
    expect(spec.role('es'), 'Rol');
    expect(spec.role('zh'), 'Role'); // fallback a inglés
    expect(spec.system('es'), 'sys es');
    expect(spec.system('zh'), 'sys en'); // fallback a inglés
    expect(spec.crisisGuardrails, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/agent_catalog_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../agent_spec.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/modules/ai/agents/agent_spec.dart
import 'package:flutter/material.dart';

/// De dónde saca el agente su evidencia antes de generar.
enum GroundingMode {
  /// Guías de emergencia primero, luego biblioteca (Vera, Norte).
  guidesFirst,

  /// Toda la biblioteca ZIM instalada, con citas (Sabio, Bruno).
  library,

  /// Sin recuperación; el prompt lo es todo (Lía traductora).
  none,
}

/// Un especialista local: identidad + prompt experto + fuentes + modelo.
/// Dato puro y testeable; no toca el motor ni la UI.
class AgentSpec {
  const AgentSpec({
    required this.id,
    required this.nameProper,
    required this.roleByLang,
    required this.avatar,
    required this.accent,
    required this.modelId,
    required this.grounding,
    required this.temperature,
    required this.systemByLang,
    required this.quickChipKeys,
    this.crisisGuardrails = false,
  });

  final String id;
  final String nameProper; // no se traduce
  final Map<String, String> roleByLang;
  final IconData avatar;
  final Color accent;
  final String modelId; // clave en ModelCatalog
  final GroundingMode grounding;
  final double temperature;
  final Map<String, String> systemByLang;
  final List<String> quickChipKeys;
  final bool crisisGuardrails;

  /// Rol localizado: idioma pedido → inglés → español → id.
  String role(String lang) =>
      roleByLang[lang] ?? roleByLang['en'] ?? roleByLang['es'] ?? id;

  /// System prompt: idioma pedido → inglés → español → cadena vacía.
  String system(String lang) =>
      systemByLang[lang] ?? systemByLang['en'] ?? systemByLang['es'] ?? '';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/agent_catalog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/ai/agents/agent_spec.dart test/agent_catalog_test.dart
git commit -m "feat(ai): AgentSpec — especialista local como dato puro"
```

---

## Task 2: Catálogo de 6 agentes en 7 idiomas

**Files:**
- Create: `lib/modules/ai/agents/agent_catalog.dart`
- Test: `test/agent_catalog_test.dart` (añadir)

- [ ] **Step 1: Write the failing test (añadir al archivo existente)**

```dart
// test/agent_catalog_test.dart — añadir dentro de main()
import 'package:nuvok/modules/ai/agents/agent_catalog.dart';

  test('los 6 agentes existen con rol y system en los 7 idiomas', () {
    const langs = ['es', 'en', 'pt', 'fr', 'zh', 'ja', 'ht'];
    expect(AgentCatalog.all.map((a) => a.id).toSet(),
        {'medic', 'psychologist', 'engineer', 'survival', 'translator', 'librarian'});
    for (final a in AgentCatalog.all) {
      for (final l in langs) {
        expect(a.roleByLang[l], isNotNull, reason: '${a.id} rol sin $l');
        expect(a.systemByLang[l]?.trim(), isNotEmpty,
            reason: '${a.id} system sin $l');
      }
    }
  });

  test('byId encuentra y devuelve null si no existe', () {
    expect(AgentCatalog.byId('medic')?.nameProper, 'Vera');
    expect(AgentCatalog.byId('nope'), isNull);
  });

  test('el psicólogo activa guardrails de crisis', () {
    expect(AgentCatalog.byId('psychologist')!.crisisGuardrails, isTrue);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/agent_catalog_test.dart`
Expected: FAIL — `AgentCatalog` no existe.

- [ ] **Step 3: Write implementation**

Crear `lib/modules/ai/agents/agent_catalog.dart`. Cada system prompt sigue el patrón validado: fija el idioma por nombre nativo y termina reforzándolo. Contenido completo (los 7 idiomas por agente; abreviado aquí sólo donde el patrón se repite palabra por palabra — el implementador DEBE escribir los 7, usando estas traducciones):

```dart
// lib/modules/ai/agents/agent_catalog.dart
import 'package:flutter/material.dart';
import 'agent_spec.dart';

/// Nombre nativo del idioma para fijar la RESPUESTA (los modelos pequeños
/// obedecen una instrucción explícita mejor que "el idioma del usuario").
const _langName = {
  'es': 'español', 'en': 'English', 'pt': 'português', 'fr': 'français',
  'zh': '中文', 'ja': '日本語', 'ht': 'kreyòl ayisyen',
};

/// Construye un system prompt de [core] (una frase de personalidad por idioma)
/// añadiendo el pin de idioma al final. Evita repetir la coletilla 7×6 veces.
Map<String, String> _sys(Map<String, String> core) => {
      for (final e in core.entries)
        e.key: '${e.value} Responde SIEMPRE en ${_langName[e.key]}.',
    };

class AgentCatalog {
  static const List<AgentSpec> all = [
    AgentSpec(
      id: 'medic',
      nameProper: 'Vera',
      roleByLang: {
        'es': 'Médica de emergencia', 'en': 'Emergency medic',
        'pt': 'Médica de emergência', 'fr': 'Médecin d\'urgence',
        'zh': '急救医生', 'ja': '救急医', 'ht': 'Doktè ijans',
      },
      avatar: Icons.emergency,
      accent: Color(0xFFD32F2F),
      modelId: 'general-1.7b',
      grounding: GroundingMode.guidesFirst,
      temperature: 0.5,
      systemByLang: _medicSys,
      quickChipKeys: ['aiQuickRcp', 'aiQuickChoking', 'aiQuickBleeding', 'aiQuickBurn'],
    ),
    AgentSpec(
      id: 'psychologist',
      nameProper: 'Elías',
      roleByLang: {
        'es': 'Apoyo psicológico', 'en': 'Psychological support',
        'pt': 'Apoio psicológico', 'fr': 'Soutien psychologique',
        'zh': '心理支持', 'ja': '心理サポート', 'ht': 'Sipò sikolojik',
      },
      avatar: Icons.self_improvement,
      accent: Color(0xFF6A1B9A),
      modelId: 'general-1.7b',
      grounding: GroundingMode.guidesFirst,
      temperature: 0.7,
      systemByLang: _psychSys,
      quickChipKeys: [],
      crisisGuardrails: true,
    ),
    AgentSpec(
      id: 'engineer',
      nameProper: 'Bruno',
      roleByLang: {
        'es': 'Ingeniero de campo', 'en': 'Field engineer',
        'pt': 'Engenheiro de campo', 'fr': 'Ingénieur de terrain',
        'zh': '现场工程师', 'ja': '現場エンジニア', 'ht': 'Enjenyè teren',
      },
      avatar: Icons.build,
      accent: Color(0xFF00695C),
      modelId: 'general-1.7b',
      grounding: GroundingMode.library,
      temperature: 0.6,
      systemByLang: _engineerSys,
      quickChipKeys: [],
    ),
    AgentSpec(
      id: 'survival',
      nameProper: 'Norte',
      roleByLang: {
        'es': 'Guía de supervivencia', 'en': 'Survival guide',
        'pt': 'Guia de sobrevivência', 'fr': 'Guide de survie',
        'zh': '生存向导', 'ja': 'サバイバルガイド', 'ht': 'Gid siviv',
      },
      avatar: Icons.terrain,
      accent: Color(0xFF2E7D32),
      modelId: 'general-1.7b',
      grounding: GroundingMode.guidesFirst,
      temperature: 0.6,
      systemByLang: _survivalSys,
      quickChipKeys: ['aiQuickModeWater', 'aiQuickModeDanger'],
    ),
    AgentSpec(
      id: 'translator',
      nameProper: 'Lía',
      roleByLang: {
        'es': 'Traductora', 'en': 'Translator', 'pt': 'Tradutora',
        'fr': 'Traductrice', 'zh': '翻译', 'ja': '翻訳者', 'ht': 'Tradiktè',
      },
      avatar: Icons.translate,
      accent: Color(0xFF1565C0),
      modelId: 'translate-0.6b',
      grounding: GroundingMode.none,
      temperature: 0.3,
      systemByLang: _translatorSys,
      quickChipKeys: [],
    ),
    AgentSpec(
      id: 'librarian',
      nameProper: 'Sabio',
      roleByLang: {
        'es': 'Bibliotecario', 'en': 'Librarian', 'pt': 'Bibliotecário',
        'fr': 'Bibliothécaire', 'zh': '图书管理员', 'ja': '司書', 'ht': 'Bibliyotekè',
      },
      avatar: Icons.menu_book,
      accent: Color(0xFF8D6E63),
      modelId: 'general-1.7b',
      grounding: GroundingMode.library,
      temperature: 0.6,
      systemByLang: _librarianSys,
      quickChipKeys: [],
    ),
  ];

  static AgentSpec? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}

// El implementador escribe la frase de personalidad por idioma; _sys() añade
// el pin de idioma. Debe cubrir los 7 códigos: es,en,pt,fr,zh,ja,ht.
final Map<String, String> _medicSys = _sys({
  'es': 'Eres Vera, médica de emergencia de Nuvok. Da pasos numerados, cortos '
      'y accionables; primero la seguridad de la escena; recuerda buscar ayuda '
      'profesional. Cita las fuentes [n].',
  'en': 'You are Vera, Nuvok\'s emergency medic. Give short numbered, '
      'actionable steps; scene safety first; remind the user to seek '
      'professional help. Cite sources [n].',
  'pt': 'Você é Vera, médica de emergência da Nuvok. Dê passos numerados, '
      'curtos e acionáveis; segurança da cena primeiro; lembre de buscar ajuda '
      'profissional. Cite as fontes [n].',
  'fr': 'Tu es Vera, médecin d\'urgence de Nuvok. Donne des étapes numérotées, '
      'courtes et concrètes; sécurité de la scène d\'abord; rappelle de '
      'chercher de l\'aide professionnelle. Cite les sources [n].',
  'zh': '你是 Nuvok 的急救医生 Vera。给出简短、可执行的编号步骤；先确保现场安全；'
      '提醒寻求专业帮助。引用来源 [n]。',
  'ja': 'あなたは Nuvok の救急医 Vera です。短く実行可能な番号付きの手順を示し、'
      'まず現場の安全を確保し、専門家の助けを求めるよう伝えてください。出典を [n] で示します。',
  'ht': 'Ou se Vera, doktè ijans Nuvok. Bay etap ki nimewote, kout e ki ka '
      'aji; sekirite sèn nan an premye; sonje mande èd pwofesyonèl. Site sous [n].',
});

final Map<String, String> _psychSys = _sys({
  'es': 'Eres Elías, apoyo psicológico de Nuvok. Escucha con calma, valida las '
      'emociones y ofrece técnicas simples (respiración, aterrizaje). NO '
      'diagnosticas ni recetas. Si hay señales de peligro para la vida, urge a '
      'buscar ayuda inmediata.',
  'en': 'You are Elías, Nuvok\'s psychological support. Listen calmly, validate '
      'emotions, offer simple techniques (breathing, grounding). Do NOT '
      'diagnose or prescribe. If there are signs of danger to life, urge '
      'seeking immediate help.',
  'pt': 'Você é Elías, apoio psicológico da Nuvok. Ouça com calma, valide as '
      'emoções, ofereça técnicas simples (respiração, ancoragem). NÃO '
      'diagnostique nem receite. Havendo sinais de risco de vida, oriente '
      'buscar ajuda imediata.',
  'fr': 'Tu es Elías, soutien psychologique de Nuvok. Écoute calmement, valide '
      'les émotions, propose des techniques simples (respiration, ancrage). Ne '
      'diagnostique NI ne prescris. En cas de danger vital, incite à chercher '
      'de l\'aide immédiate.',
  'zh': '你是 Nuvok 的心理支持 Elías。平静倾听，认可情绪，提供简单技巧（呼吸、着陆）。'
      '不要诊断或开处方。若有危及生命的迹象，敦促立即求助。',
  'ja': 'あなたは Nuvok の心理サポート Elías です。落ち着いて聴き、感情を受け止め、'
      '簡単な技法（呼吸・グラウンディング）を示します。診断や処方はしません。'
      '生命の危険の兆候があれば直ちに助けを求めるよう促します。',
  'ht': 'Ou se Elías, sipò sikolojik Nuvok. Koute ak kalm, valide emosyon yo, '
      'bay teknik senp (respirasyon, ankraj). PA dyagnostike ni preskri. Si gen '
      'siy danje pou lavi, ankouraje chèche èd imedyat.',
});

final Map<String, String> _engineerSys = _sys({
  'es': 'Eres Bruno, ingeniero de campo de Nuvok. Resuelve problemas prácticos '
      '(agua, energía, reparaciones, estructuras) con pasos claros y materiales '
      'a mano. Cita las fuentes [n] cuando uses la biblioteca.',
  'en': 'You are Bruno, Nuvok\'s field engineer. Solve practical problems '
      '(water, power, repairs, structures) with clear steps and on-hand '
      'materials. Cite sources [n] when using the library.',
  'pt': 'Você é Bruno, engenheiro de campo da Nuvok. Resolva problemas práticos '
      '(água, energia, reparos, estruturas) com passos claros e materiais à '
      'mão. Cite as fontes [n] ao usar a biblioteca.',
  'fr': 'Tu es Bruno, ingénieur de terrain de Nuvok. Résous des problèmes '
      'pratiques (eau, énergie, réparations, structures) avec des étapes '
      'claires et des matériaux disponibles. Cite les sources [n].',
  'zh': '你是 Nuvok 的现场工程师 Bruno。用清晰步骤和手边材料解决实际问题'
      '（水、电、维修、结构）。使用资料库时引用来源 [n]。',
  'ja': 'あなたは Nuvok の現場エンジニア Bruno です。手元の材料と明確な手順で'
      '実用的な問題（水・電力・修理・構造）を解決します。資料を使うときは出典を [n] で示します。',
  'ht': 'Ou se Bruno, enjenyè teren Nuvok. Rezoud pwoblèm pratik (dlo, enèji, '
      'reparasyon, estrikti) ak etap klè e materyèl ki disponib. Site sous [n].',
});

final Map<String, String> _survivalSys = _sys({
  'es': 'Eres Norte, guía de supervivencia de Nuvok. Prioriza agua, refugio, '
      'fuego y señalización según el entorno del usuario. Pasos concretos con '
      'medidas. Cita las fuentes [n].',
  'en': 'You are Norte, Nuvok\'s survival guide. Prioritize water, shelter, '
      'fire and signaling for the user\'s environment. Concrete steps with '
      'measurements. Cite sources [n].',
  'pt': 'Você é Norte, guia de sobrevivência da Nuvok. Priorize água, abrigo, '
      'fogo e sinalização conforme o ambiente. Passos concretos com medidas. '
      'Cite as fontes [n].',
  'fr': 'Tu es Norte, guide de survie de Nuvok. Priorise l\'eau, l\'abri, le '
      'feu et la signalisation selon l\'environnement. Étapes concrètes avec '
      'mesures. Cite les sources [n].',
  'zh': '你是 Nuvok 的生存向导 Norte。按用户所处环境优先处理水、庇护、火与信号。'
      '给出带具体量度的步骤。引用来源 [n]。',
  'ja': 'あなたは Nuvok のサバイバルガイド Norte です。環境に応じて水・避難所・火・'
      '合図を優先します。具体的な数値を伴う手順を示し、出典を [n] で示します。',
  'ht': 'Ou se Norte, gid siviv Nuvok. Bay priyorite dlo, abri, dife ak siyal '
      'selon anviwònman an. Etap konkrè ak mezi. Site sous [n].',
});

final Map<String, String> _translatorSys = _sys({
  'es': 'Eres Lía, traductora de Nuvok. Traduce el texto del usuario con '
      'fidelidad y naturalidad. Devuelve SOLO la traducción, sin explicaciones.',
  'en': 'You are Lía, Nuvok\'s translator. Translate the user\'s text '
      'faithfully and naturally. Return ONLY the translation, no explanations.',
  'pt': 'Você é Lía, tradutora da Nuvok. Traduza o texto do usuário com '
      'fidelidade e naturalidade. Devolva APENAS a tradução, sem explicações.',
  'fr': 'Tu es Lía, traductrice de Nuvok. Traduis le texte de l\'utilisateur '
      'fidèlement et naturellement. Ne renvoie QUE la traduction, sans '
      'explications.',
  'zh': '你是 Nuvok 的翻译 Lía。忠实自然地翻译用户文本。只返回译文，不要解释。',
  'ja': 'あなたは Nuvok の翻訳者 Lía です。ユーザーの文を忠実かつ自然に翻訳します。'
      '訳文のみを返し、説明はしません。',
  'ht': 'Ou se Lía, tradiktè Nuvok. Tradui tèks itilizatè a fidèlman e '
      'natirèlman. Bay SÈLMAN tradiksyon an, san esplikasyon.',
});

final Map<String, String> _librarianSys = _sys({
  'es': 'Eres Sabio, bibliotecario de Nuvok. Responde SOLO con base en las '
      'FUENTES de la biblioteca offline; cita cada afirmación [n]; si no está '
      'en las fuentes, dilo y no inventes.',
  'en': 'You are Sabio, Nuvok\'s librarian. Answer ONLY from the offline '
      'library SOURCES; cite every claim [n]; if it is not in the sources, say '
      'so and do not invent.',
  'pt': 'Você é Sabio, bibliotecário da Nuvok. Responda SOMENTE com base nas '
      'FONTES da biblioteca offline; cite cada afirmação [n]; se não estiver '
      'nas fontes, diga isso e não invente.',
  'fr': 'Tu es Sabio, bibliothécaire de Nuvok. Réponds UNIQUEMENT à partir des '
      'SOURCES de la bibliothèque hors ligne; cite chaque affirmation [n]; si '
      'ce n\'est pas dans les sources, dis-le et n\'invente pas.',
  'zh': '你是 Nuvok 的图书管理员 Sabio。只根据离线资料库的来源回答；每条陈述都引用 [n]；'
      '若来源中没有，就说明并且不要编造。',
  'ja': 'あなたは Nuvok の司書 Sabio です。オフライン資料の出典のみに基づいて答え、'
      '各主張に [n] を付け、出典になければそう述べ、作り話をしません。',
  'ht': 'Ou se Sabio, bibliyotekè Nuvok. Reponn SÈLMAN dapre SOUS bibliyotèk '
      'san entènèt la; site chak afimasyon [n]; si li pa nan sous yo, di sa e pa '
      'envante.',
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/agent_catalog_test.dart`
Expected: PASS (3 tests nuevos + el de Task 1).

- [ ] **Step 5: Commit**

```bash
git add lib/modules/ai/agents/agent_catalog.dart test/agent_catalog_test.dart
git commit -m "feat(ai): catálogo de 6 especialistas en 7 idiomas"
```

---

## Task 3: `ModelCatalog`

**Files:**
- Create: `lib/modules/ai/agents/model_catalog.dart`
- Test: `test/model_catalog_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/model_catalog_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/model_catalog.dart';
import 'package:nuvok/modules/ai/agents/agent_catalog.dart';

void main() {
  test('cada modelId de agente existe en el catálogo de modelos', () {
    for (final a in AgentCatalog.all) {
      expect(ModelCatalog.byId(a.modelId), isNotNull,
          reason: '${a.id} apunta a modelId inexistente ${a.modelId}');
    }
  });

  test('byId devuelve null si no existe', () {
    expect(ModelCatalog.byId('nope'), isNull);
  });

  test('cada entrada tiene url, fileName y sha256 no vacíos', () {
    for (final m in ModelCatalog.all) {
      expect(m.fileName.endsWith('.gguf'), isTrue);
      expect(m.url, startsWith('https://'));
      expect(m.sha256, isNotEmpty);
      expect(m.sizeBytes, greaterThan(0));
    }
  });

  test('el fallback ligero, si existe, apunta a una entrada real', () {
    for (final m in ModelCatalog.all) {
      if (m.liteFallbackId != null) {
        expect(ModelCatalog.byId(m.liteFallbackId!), isNotNull);
      }
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/model_catalog_test.dart`
Expected: FAIL — `ModelCatalog` no existe.

- [ ] **Step 3: Write implementation**

`sizeBytes`/`sha256` son marcadores hasta subir los binarios (Task 8); los tests sólo exigen que sean no vacíos y coherentes.

```dart
// lib/modules/ai/agents/model_catalog.dart

/// Un modelo GGUF descargable. Un mismo modelo corre en iOS/Android/macOS;
/// no hay variantes por plataforma (la adaptación es runtime en AiEngine).
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
  final String sha256;

  /// Modelo menor a usar si este no cabe en la RAM libre. null = no hay.
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
```

**Nota:** `sha256: 'TO_FILL_ON_UPLOAD'` es intencional y se resuelve en Task 8; el test sólo verifica no-vacío. NO es un placeholder de lógica.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/model_catalog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/ai/agents/model_catalog.dart test/model_catalog_test.dart
git commit -m "feat(ai): catálogo único de modelos GGUF (multiplataforma)"
```

---

## Task 4: Verificación sha256 en `DownloadManager`

**Files:**
- Modify: `lib/modules/depot/download_manager.dart`
- Test: `test/download_sha256_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/download_sha256_test.dart
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/depot/download_manager.dart';

void main() {
  test('descarga con sha256 correcto queda "done"; con incorrecto, "error"',
      () async {
    final body = List<int>.generate(2048, (i) => i % 256);
    final good = sha256.convert(body).toString();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) {
      req.response
        ..add(body)
        ..close();
    });
    final url = 'http://127.0.0.1:${server.port}/model.gguf';
    final dir = await Directory.systemTemp.createTemp('dl');
    final dm = DownloadManager.instance;

    // sha256 correcto
    final okPath = '${dir.path}/ok.gguf';
    dm.enqueue(url, okPath, sha256Hex: good);
    await _waitDone(dm, okPath);
    expect(File(okPath).existsSync(), isTrue);

    // sha256 incorrecto: no debe dejar el archivo final
    final badPath = '${dir.path}/bad.gguf';
    dm.enqueue(url, badPath, sha256Hex: 'deadbeef');
    await _waitError(dm, badPath);
    expect(File(badPath).existsSync(), isFalse);

    await server.close(force: true);
  });
}

Future<void> _waitDone(DownloadManager dm, String path) async {
  for (var i = 0; i < 100; i++) {
    if (File(path).existsSync()) return;
    await Future.delayed(const Duration(milliseconds: 50));
  }
  fail('descarga no completó');
}

Future<void> _waitError(DownloadManager dm, String path) async {
  for (var i = 0; i < 100; i++) {
    final t = dm.tasks.where((t) => t.destPath == path);
    if (t.isNotEmpty && t.first.status == DownloadStatus.error) return;
    await Future.delayed(const Duration(milliseconds: 50));
  }
  fail('descarga no marcó error');
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/download_sha256_test.dart`
Expected: FAIL — `enqueue` no acepta `sha256Hex`.

- [ ] **Step 3: Write implementation**

En `download_manager.dart`: import `package:crypto/crypto.dart` y `dart:convert`; añadir campo `sha256Hex` a `DownloadTask`; pasarlo por `enqueue`; verificar en `_finish` antes del rename.

```dart
// arriba, con los imports
import 'package:crypto/crypto.dart';

// en DownloadTask: añadir al constructor y como campo
class DownloadTask {
  DownloadTask({
    required this.url,
    required this.destPath,
    this.totalBytes,
    this.sha256Hex,
  });
  // ... campos existentes ...
  final String? sha256Hex; // hash esperado; null = sin verificación
```

```dart
// enqueue: propagar el hash
void enqueue(String url, String destPath, {int? totalBytes, String? sha256Hex}) {
  if (File(destPath).existsSync()) return;
  if (tasks.any(
      (t) => t.destPath == destPath && t.status != DownloadStatus.error)) {
    return;
  }
  tasks.add(DownloadTask(
      url: url, destPath: destPath, totalBytes: totalBytes, sha256Hex: sha256Hex));
  notifyListeners();
  _pump();
}
```

```dart
// _finish: verificar hash del .part ANTES del rename
Future<void> _finish(DownloadTask task) async {
  if (task.sha256Hex != null) {
    final digest = await sha256.bind(task.partFile.openRead()).first;
    if (digest.toString() != task.sha256Hex) {
      try {
        task.partFile.deleteSync();
      } catch (_) {}
      task.status = DownloadStatus.error;
      task.error = 'Verificación fallida: el archivo llegó corrupto';
      notifyListeners();
      return;
    }
  }
  final slash = task.destPath.lastIndexOf('/');
  if (slash > 0) {
    await Directory(task.destPath.substring(0, slash)).create(recursive: true);
  }
  await task.partFile.rename(task.destPath);
  task.status = DownloadStatus.done;
  task.received = File(task.destPath).lengthSync();
  task.totalBytes = task.received;
  notifyListeners();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/download_sha256_test.dart`
Expected: PASS.

Verificar sin regresión el resto de descargas:
Run: `flutter test test/download_from_here_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/depot/download_manager.dart test/download_sha256_test.dart
git commit -m "feat(depot): verificación sha256 opcional antes de instalar"
```

---

## Task 5: `AgentRuntime` — resolución de estado y guard de RAM

**Files:**
- Create: `lib/modules/ai/agents/agent_runtime.dart`
- Test: `test/agent_runtime_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/agent_runtime_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/agent_runtime.dart';
import 'package:nuvok/modules/ai/agents/model_catalog.dart';

void main() {
  final big = ModelCatalog.byId('general-1.7b')!;

  test('resuelve READY cuando el modelo está instalado', () {
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {big.fileName},
      freeRamBytes: 6000000000,
    );
    expect(s.state, AgentInstallState.ready);
    expect(s.effectiveModel.id, big.id);
  });

  test('resuelve NEEDS_DOWNLOAD cuando no está', () {
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: const {},
      freeRamBytes: 6000000000,
    );
    expect(s.state, AgentInstallState.needsDownload);
  });

  test('con RAM insuficiente y modelo instalado, ofrece el fallback ligero', () {
    final lite = ModelCatalog.byId(big.liteFallbackId!)!;
    final s = AgentRuntime.resolve(
      model: big,
      installedFileNames: {big.fileName, lite.fileName},
      freeRamBytes: 1000000000, // no cabe 1.7B (~1.1GB * 0.8 guard)
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/agent_runtime_test.dart`
Expected: FAIL — `AgentRuntime` no existe.

- [ ] **Step 3: Write implementation**

```dart
// lib/modules/ai/agents/agent_runtime.dart
import 'model_catalog.dart';

enum AgentInstallState {
  ready,          // modelo (o su fallback) listo para cargar
  needsDownload,  // hay que descargar el modelo principal
  needsLite,      // no cabe en RAM y el fallback ligero no está instalado
}

class AgentStatus {
  const AgentStatus({
    required this.state,
    required this.effectiveModel,
    required this.usingLiteFallback,
  });
  final AgentInstallState state;
  final ModelEntry effectiveModel; // el que se cargaría de verdad
  final bool usingLiteFallback;
}

class AgentRuntime {
  /// Fracción de la RAM libre que un modelo puede ocupar sin arriesgar un
  /// cierre por presión de memoria (jetsam en iOS, OOM en Android).
  static const double ramSafety = 0.8;

  static bool _fits(ModelEntry m, int? freeRamBytes) =>
      freeRamBytes == null || m.sizeBytes <= freeRamBytes * ramSafety;

  /// Decide el estado de un agente a partir de datos puros: qué modelos hay
  /// instalados y cuánta RAM libre hay. Sin IO — testeable y determinista.
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
    // No cabe: intentar el ligero.
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
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/agent_runtime_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/modules/ai/agents/agent_runtime.dart test/agent_runtime_test.dart
git commit -m "feat(ai): AgentRuntime — estado de instalación y guard de RAM"
```

---

## Task 6: Claves i18n para agentes

**Files:**
- Modify: `lib/core/locale_service.dart`
- Test: `test/agent_i18n_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/agent_i18n_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';

void main() {
  test('las claves de UI de agentes existen en es+en', () {
    const keys = [
      'agentsTitle', 'agentPick', 'agentReady', 'agentDownload',
      'agentLiteMode', 'agentSwitching', 'agentAdvancedModel',
    ];
    for (final k in keys) {
      final map = AppStrings.allKeys[k];
      expect(map, isNotNull, reason: 'falta clave $k');
      expect(map!['es'], isNotNull, reason: '$k sin es');
      expect(map['en'], isNotNull, reason: '$k sin en');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/agent_i18n_test.dart`
Expected: FAIL — claves ausentes.

- [ ] **Step 3: Write implementation**

Añadir al mapa `allKeys` en `locale_service.dart` (junto a las otras claves `ai*`), cada una con los 7 idiomas:

```dart
    'agentsTitle': {
      'es': 'Especialistas', 'en': 'Specialists', 'pt': 'Especialistas',
      'fr': 'Spécialistes', 'zh': '专家', 'ja': 'スペシャリスト', 'ht': 'Espesyalis',
    },
    'agentPick': {
      'es': 'Elige un especialista', 'en': 'Choose a specialist',
      'pt': 'Escolha um especialista', 'fr': 'Choisis un spécialiste',
      'zh': '选择一位专家', 'ja': 'スペシャリストを選ぶ', 'ht': 'Chwazi yon espesyalis',
    },
    'agentReady': {
      'es': 'Listo', 'en': 'Ready', 'pt': 'Pronto',
      'fr': 'Prêt', 'zh': '就绪', 'ja': '準備完了', 'ht': 'Pare',
    },
    'agentDownload': {
      'es': 'Descargar', 'en': 'Download', 'pt': 'Baixar',
      'fr': 'Télécharger', 'zh': '下载', 'ja': 'ダウンロード', 'ht': 'Telechaje',
    },
    'agentLiteMode': {
      'es': 'Modo ligero', 'en': 'Lite mode', 'pt': 'Modo leve',
      'fr': 'Mode léger', 'zh': '轻量模式', 'ja': '軽量モード', 'ht': 'Mòd lejè',
    },
    'agentSwitching': {
      'es': 'Cambiando de especialista…', 'en': 'Switching specialist…',
      'pt': 'Trocando de especialista…', 'fr': 'Changement de spécialiste…',
      'zh': '正在切换专家…', 'ja': 'スペシャリストを切り替え中…', 'ht': 'Chanje espesyalis…',
    },
    'agentAdvancedModel': {
      'es': 'Modelo manual (avanzado)', 'en': 'Manual model (advanced)',
      'pt': 'Modelo manual (avançado)', 'fr': 'Modèle manuel (avancé)',
      'zh': '手动模型（高级）', 'ja': '手動モデル（詳細）', 'ht': 'Modèl manyèl (avanse)',
    },
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/agent_i18n_test.dart test/locale_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/locale_service.dart test/agent_i18n_test.dart
git commit -m "feat(i18n): claves de UI para la pestaña de especialistas"
```

---

## Task 7: Pestaña Asistente — cuadrícula de agentes + chat con cabecera

**Files:**
- Modify: `lib/modules/ai/ai_page.dart`
- Test: `test/ai_page_test.dart` (extender), `test/agent_page_test.dart` (nuevo)

Esta tarea reescribe `ai_page.dart`. Se hace en 3 sub-pasos para mantener commits pequeños.

- [ ] **Step 1: Write the failing widget test para la cuadrícula**

```dart
// test/agent_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/core/nuvok_library.dart';
import 'package:nuvok/modules/ai/ai_page.dart';

void main() {
  testWidgets('la pestaña abre con la cuadrícula de los 6 especialistas',
      (tester) async {
    final tmp = await Directory.systemTemp.createTemp('lib');
    NuvokLibrary.setInstanceForTest(tmp);
    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        notifier: LocaleService.instance,
        child: const AiPage(),
      ),
    ));
    await tester.pumpAndSettle();
    // Los seis nombres propios visibles como tarjetas.
    for (final name in ['Vera', 'Elías', 'Bruno', 'Norte', 'Lía', 'Sabio']) {
      expect(find.text(name), findsOneWidget, reason: 'falta tarjeta $name');
    }
  });
}
```

Confirmar la firma real de `LocaleProvider` antes de escribir el test:
Run: `grep -n "class LocaleProvider\|LocaleProvider(" lib/core/locale_service.dart`
Ajustar el `LocaleProvider(...)` del test a la firma encontrada.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/agent_page_test.dart`
Expected: FAIL — la página sigue mostrando el dropdown, no las tarjetas.

- [ ] **Step 3: Reescribir `ai_page.dart` — vista de cuadrícula**

`AiPage` pasa a tener dos modos internos: `_AgentGrid` (por defecto) y `_AgentChat` (cuando hay agente seleccionado). Estructura:

```dart
// ai_page.dart (esqueleto de la reescritura)
class _AiPageState extends State<AiPage> {
  AgentSpec? _agent; // null = mostrando la cuadrícula

  @override
  Widget build(BuildContext context) {
    if (_agent == null) {
      return _AgentGrid(onPick: (a) => setState(() => _agent = a));
    }
    return _AgentChat(
      agent: _agent!,
      onBack: () => setState(() => _agent = null),
    );
  }
}
```

`_AgentGrid`: `GridView` de `AgentCatalog.all`; cada tarjeta muestra `avatar`, `nameProper`, `role(lang)` y una etiqueta de estado calculada con `AgentRuntime.resolve(...)` usando `NuvokLibrary.instance.listModels()` (nombres de archivo instalados) y `AiEngine.freeRamBytes()`. El estado se resuelve en `FutureBuilder` (freeRam es async). Etiqueta: `ready`→`tr('agentReady')`, `needsDownload`→`tr('agentDownload')`, `needsLite`→`tr('agentLiteMode')`.

`_AgentChat`: es el chat actual, con estos cambios:
- Cabecera (`AppBar`) muestra avatar + `nameProper` + `role(lang)` del agente, con botón atrás que llama `onBack`.
- `systemPrompt` inicial = `agent.system(lang)` en vez de `_systemPromptForLanguage()`.
- El grounding se elige por `agent.grounding` (ver Task 8 para el cableado fino); en este paso, mantener el grounding actual como stub condicionado a `agent.grounding != GroundingMode.none`.
- Los chips rápidos salen de `agent.quickChipKeys`.
- El reminder de idioma pegado a la pregunta (ya implementado) se conserva.
- Eliminar el `DropdownButtonFormField` de modelos y los `Switch` de biblioteca/emergencia del `AppBar`.

Mantener `AiEmptyState`, `_ServerButton`, `_Bubble` (se reusan dentro de `_AgentChat`).

- [ ] **Step 4: Run tests**

Run: `flutter test test/agent_page_test.dart test/ai_page_test.dart`
Expected: PASS. Si `ai_page_test.dart` probaba el dropdown viejo, actualizar esa aserción al nuevo estado vacío/cuadrícula.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/ai/ai_page.dart test/agent_page_test.dart test/ai_page_test.dart
git commit -m "feat(ai): pestaña de especialistas — cuadrícula + chat con cabecera"
```

- [ ] **Step 6: Cablear grounding por agente + descarga/instalación**

En `_AgentChat._send`, elegir grounding según `agent.grounding`:
- `guidesFirst` → `EmergencyRetriever.retrieve(...)` + `buildEmergencySystemPrompt(..., replyLang: lang)` (Vera, Norte, Elías).
- `library` → `LibraryRetriever.retrieve(...)` + `buildGroundedSystemPrompt(..., replyLang: lang)` (Sabio, Bruno).
- `none` → sólo `agent.system(lang)` (Lía).

En la tarjeta con estado `needsDownload`, el botón encola:
```dart
final m = ModelCatalog.byId(agent.modelId)!;
DownloadManager.instance.enqueue(
  m.url, '${NuvokLibrary.instance.modelsDir.path}/${m.fileName}',
  totalBytes: m.sizeBytes, sha256Hex: m.sha256 == 'TO_FILL_ON_UPLOAD' ? null : m.sha256);
```
(Mientras el sha256 sea el marcador, se pasa `null` para no romper la verificación; al subir binarios reales, la verificación se activa sola.)

Al abrir el chat, cargar el modelo efectivo:
```dart
final status = AgentRuntime.resolve(
  model: ModelCatalog.byId(agent.modelId)!,
  installedFileNames: NuvokLibrary.instance.listModels()
      .map((f) => f.uri.pathSegments.last).toSet(),
  freeRamBytes: await AiEngine.freeRamBytes());
if (status.state == AgentInstallState.ready) {
  await AiEngine.instance.start(
    '${NuvokLibrary.instance.modelsDir.path}/${status.effectiveModel.fileName}');
}
```
Guardrails del psicólogo: si `agent.crisisGuardrails` y la pregunta contiene términos de crisis (lista mínima en `agent_runtime.dart`: 'suicid', 'matarme', 'kill myself', etc.), anteponer a la respuesta el botón/《aviso》 SOS existente (`tr('sos')`).

- [ ] **Step 7: Commit**

```bash
git add lib/modules/ai/ai_page.dart lib/modules/ai/agents/agent_runtime.dart
git commit -m "feat(ai): grounding por agente, descarga de modelo y guardrails"
```

---

## Task 8: Modo avanzado en Ajustes + relleno del catálogo real

**Files:**
- Modify: `lib/modules/settings/settings_page.dart`
- Modify: `lib/modules/ai/agents/model_catalog.dart` (sha256/size reales)

- [ ] **Step 1: Añadir "modelo manual" en Ajustes**

En `settings_page.dart`, añadir una entrada (sección avanzada) que abre un selector de archivo `.gguf` (`file_selector`, ya usado en Depot) y lo copia a `NuvokLibrary.instance.modelsDir`. Etiqueta: `tr('agentAdvancedModel')`. Esto preserva el flujo experto que la cuadrícula ya no expone.

- [ ] **Step 2: Verificar compilación y análisis**

Run: `flutter analyze lib/modules/ai lib/modules/settings lib/modules/depot`
Expected: `No issues found!`

- [ ] **Step 3: Subir binarios y rellenar catálogo (tarea de release, fuera de Flutter)**

Subir los 3 GGUF a `https://nuvok.org/models/`. Calcular sha256:
```bash
shasum -a 256 qwen3-1.7b-instruct-q4_k_m.gguf
```
Reemplazar cada `sha256: 'TO_FILL_ON_UPLOAD'` y `sizeBytes` por el valor real en `model_catalog.dart`. Con esto la verificación de Task 4 se activa automáticamente.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/settings/settings_page.dart lib/modules/ai/agents/model_catalog.dart
git commit -m "feat(settings): carga manual de modelo + catálogo real de GGUF"
```

---

## Task 9: Test live end-to-end en macOS

**Files:**
- Create: `test/agent_live_test.dart`

- [ ] **Step 1: Escribir el test live (se salta sin modelo/dylib, como el de la sesión)**

```dart
// test/agent_live_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/agent_catalog.dart';
import 'package:nuvok/modules/ai/agents/library_retriever.dart' as _; // si aplica
import 'package:nuvok/modules/ai/llama_ffi.dart';

void main() {
  test('Sabio con fuente inglesa responde en español (modelo real)', () async {
    final home = Platform.environment['HOME']!;
    final model = '$home/nuvok/models/qwen2.5-0.5b-instruct-q4_k_m.gguf';
    final dylib = '${Directory.current.path}/native/out/macos/libppllm.dylib';
    if (!File(model).existsSync() || !File(dylib).existsSync()) {
      markTestSkipped('sin modelo/dylib');
      return;
    }
    FfiLlamaEngine.debugSetLibraryPath(dylib);
    final engine = await FfiLlamaEngine.load(model, nCtx: 4096);
    final sabio = AgentCatalog.byId('librarian')!;
    final reply = StringBuffer();
    await for (final p in engine.chat([
      {'role': 'system', 'content': sabio.system('es')},
      {'role': 'user', 'content': 'Boiling water kills pathogens.\n\n'
          '¿Cómo hago el agua segura para beber? Responde en español.'},
    ], maxTokens: 140, temp: 0.6)) {
      reply.write(p);
    }
    engine.dispose();
    final t = reply.toString().toLowerCase();
    // ignore: avoid_print
    print('Sabio: $reply');
    final es = ['agua', 'hervir', 'minutos', 'para'].where(t.contains).length;
    final en = ['the process', 'boiling water', 'drinking water'].where(t.contains).length;
    expect(es, greaterThan(en), reason: 'debe responder en español: $reply');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
```

Ajustar el import de `library_retriever` sólo si se usa; si no, quitarlo.

- [ ] **Step 2: Run**

Run: `flutter test test/agent_live_test.dart`
Expected: PASS en la Mac del usuario (modelo presente).

- [ ] **Step 3: Suite completa**

Run: `flutter test`
Expected: All tests passed.

- [ ] **Step 4: Commit**

```bash
git add test/agent_live_test.dart
git commit -m "test(ai): verificación live de especialista con modelo real"
```

---

## Task 10: Smoke en Android real

**Files:** ninguno (verificación manual).

- [ ] **Step 1: Compilar e instalar por WiFi (servidor LAN existente)**

Run: `flutter build apk --release` y servir con el flujo LAN ya existente del proyecto (`6f304aa`). Instalar en el Android del usuario.

- [ ] **Step 2: Verificar en dispositivo**

- Abrir Asistente → aparece la cuadrícula con 6 especialistas.
- Descargar el modelo de Vera; ver progreso y estado "Listo".
- Con la app en español, preguntarle a Sabio algo cuya fuente ZIM esté en inglés y confirmar respuesta en español.
- Si el teléfono va justo de RAM, confirmar que ofrece "Modo ligero".

- [ ] **Step 3: Registrar resultado**

Anotar en el PR/commit el modelo probado, RAM del dispositivo y captura de la respuesta en español.

---

## Self-review (cobertura de spec)

- Catálogo de 6 agentes, 7 idiomas → Task 2. ✅
- Un modelo por agente, compartible, multiplataforma → Task 3 (`ModelCatalog`, sin variantes por plataforma). ✅
- Verificación de integridad al instalar → Task 4 (sha256). ✅
- Guard de RAM con fallback ligero (obligatorio en móvil) → Task 5 (`AgentRuntime`) + cableado Task 7.6. ✅
- Identidad nombre+rol localizada → Task 2 (roleByLang) + Task 6 (claves UI). ✅
- UX cuadrícula que reemplaza dropdown/switches; emergencia→Vera; avanzado en Ajustes → Task 7 + Task 8. ✅
- Grounding por agente reutilizando retrievers → Task 7.6. ✅
- Pin de idioma en prompts → embebido en los system prompts (Task 2) y reminder ya implementado. ✅
- Degradación sin IA (Vera por guías) → grounding `guidesFirst` + `strictAnswer` existente; verificar en Task 7.6. ✅
- Testing unitario + live macOS + smoke Android → Tasks 1–6, 9, 10. ✅

**Consistencia de tipos:** `AgentSpec.role(lang)`/`system(lang)`, `ModelCatalog.byId`, `AgentRuntime.resolve → AgentStatus{state, effectiveModel, usingLiteFallback}`, `DownloadManager.enqueue(..., sha256Hex:)` — nombres usados de forma idéntica en todas las tareas. ✅
