import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/nuvok_library.dart';
import '../emergency/survival_mode.dart';
import 'emergency_retriever.dart';
import 'library_retriever.dart';
import 'ai_engine.dart';
import 'llama_server.dart' show LlamaStatus;
import '../../core/locale_service.dart';
import '../depot/download_manager.dart';
import 'agents/agent_spec.dart';
import 'agents/agent_catalog.dart';
import 'agents/agent_runtime.dart';
import 'agents/model_catalog.dart';
import 'active_model.dart';
import 'reply_lang.dart';
import '../depot/depot_page.dart';

class ChatMessage {
  ChatMessage(this.role, this.text, {this.sources = const []});
  final String role; // 'user' | 'assistant'
  String text;
  List<RetrievedSource> sources;
}

/// The Assistant tab: a grid of named specialists. Picking one opens a chat
/// bound to that specialist's expert prompt, sources and model. This replaces
/// the old raw .gguf dropdown + library/emergency switches (the manual model
/// path now lives in Settings → advanced).
class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  AgentSpec? _agent; // null = showing the specialist grid

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

/// Returns the set of installed model file names (e.g. {'qwen3-1.7b...gguf'}).
/// Ensambla el prompt del especialista: su PERSONA siempre primero, y el
/// contexto de grounding (fuentes) DESPUÉS. Antes el grounding reemplazaba la
/// persona y todos los especialistas se volvían el mismo bot genérico de
/// citas; la persona (Vera médica, Bruno ingeniero, Sabio bibliotecario…) es
/// lo que los hace especialistas y no debe perderse nunca.
String composeAgentPrompt(String persona, String groundingBlock) =>
    groundingBlock.isEmpty ? persona : '$persona\n\n$groundingBlock';

Set<String> _installedModelFileNames() =>
    NuvokLibrary.instance.listModels().map((f) => f.uri.pathSegments.last).toSet();

/// Desktops (more RAM) get the bigger specialist model; phones start a tier
/// down. See ModelCatalog.resolveClass.
bool _isDesktop() =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// The device-appropriate model an agent asks for (before install/RAM
/// fallback, which AgentRuntime.resolve then applies).
ModelEntry _modelFor(AgentSpec agent) =>
    ModelCatalog.resolveClass(agent.modelClass, isDesktop: _isDesktop());

class _AgentGrid extends StatefulWidget {
  const _AgentGrid({required this.onPick});
  final void Function(AgentSpec) onPick;

  @override
  State<_AgentGrid> createState() => _AgentGridState();
}

class _AgentGridState extends State<_AgentGrid> {
  final _dm = DownloadManager.instance;

  @override
  void initState() {
    super.initState();
    // Redraw cards as downloads progress and finish.
    _dm.addListener(_onChanged);
  }

  @override
  void dispose() {
    _dm.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _startDownload(AgentSpec agent) {
    final m = _modelFor(agent);
    _dm.enqueue(
      m.url,
      '${NuvokLibrary.instance.modelsDir.path}/${m.fileName}',
      totalBytes: m.sizeBytes,
      // While the catalog hash is the upload marker, skip verification so
      // dev/self-hosted builds still install; real hashes turn it on.
      sha256Hex: m.sha256 == 'TO_FILL_ON_UPLOAD' ? null : m.sha256,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'agentsTitle'))),
      body: FutureBuilder<int?>(
        future: AiEngine.freeRamBytes(),
        builder: (context, snap) {
          final freeRam = snap.data;
          final installed = _installedModelFileNames();
          final width = MediaQuery.of(context).size.width;
          final cols = width < 560 ? 2 : (width < 900 ? 3 : 4);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(tr(context, 'agentPick'),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: cols,
                  padding: const EdgeInsets.all(16),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                  children: [
                    for (final agent in AgentCatalog.all)
                      _AgentCard(
                        agent: agent,
                        status: _statusFor(agent, installed, freeRam),
                        downloadProgress: _progressFor(agent),
                        onOpen: () => widget.onPick(agent),
                        onDownload: () => _startDownload(agent),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  AgentStatus _statusFor(
      AgentSpec agent, Set<String> installed, int? freeRam) {
    final model = _modelFor(agent);
    return AgentRuntime.resolve(
      model: model,
      installedFileNames: installed,
      freeRamBytes: freeRam,
    );
  }

  /// Active download progress (0..1) for this agent's model, or null.
  double? _progressFor(AgentSpec agent) {
    final task = _dm.taskFor(_modelFor(agent).url);
    return task?.progress;
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.status,
    required this.downloadProgress,
    required this.onOpen,
    required this.onDownload,
  });

  final AgentSpec agent;
  final AgentStatus status;
  final double? downloadProgress;
  final VoidCallback onOpen;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleService.instance.language.code;
    final downloading = downloadProgress != null;
    final ready = status.state == AgentInstallState.ready;
    final (label, color) = switch (status.state) {
      AgentInstallState.ready => (
          status.usingLiteFallback
              ? tr(context, 'agentLiteMode')
              : tr(context, 'agentReady'),
          Colors.green,
        ),
      AgentInstallState.needsDownload => (tr(context, 'agentDownload'), null),
      AgentInstallState.needsLite => (tr(context, 'agentLiteMode'), null),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: ready ? onOpen : (downloading ? null : onDownload),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: agent.accent,
                child: Icon(agent.avatar, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 10),
              Text(agent.nameProper,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              // Flexible: en teléfonos angostos la celda queda a milímetros
              // del contenido; el rol es lo único que puede ceder (elipsis)
              // sin perder el nombre ni el estado.
              Flexible(
                child: Text(agent.role(lang),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 8),
              if (downloading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: LinearProgressIndicator(value: downloadProgress),
                )
              else if (ready && status.usingLiteFallback)
                // Corre en el modelo ligero: la fila de estado se vuelve la
                // oferta de mejora. Sin esto el usuario se queda para siempre
                // con el 0.5B incoherente sin saber que hay algo mejor (el
                // toque en el resto de la tarjeta sigue abriendo el chat).
                GestureDetector(
                  key: ValueKey('upgrade-${agent.id}'),
                  onTap: onDownload,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upgrade,
                          size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(tr(context, 'agentUpgrade'),
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      ready ? Icons.check_circle : Icons.download,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(label,
                          style: TextStyle(fontSize: 12, color: color),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentChat extends StatefulWidget {
  const _AgentChat({required this.agent, required this.onBack});
  final AgentSpec agent;
  final VoidCallback onBack;

  @override
  State<_AgentChat> createState() => _AgentChatState();
}

class _AgentChatState extends State<_AgentChat> {
  final _server = AiEngine.instance;
  final _dm = DownloadManager.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _generating = false;
  bool _loadingModel = true;

  /// Resolución modelo/RAM del último _prepareModel — alimenta el banner de
  /// mejora cuando el chat corre sobre el fallback ligero.
  AgentStatus? _status;

  /// Archivo .gguf que el motor tiene cargado (modelo activo global).
  String? _activeFile;

  bool get _hasGrounding => widget.agent.grounding != GroundingMode.none;

  @override
  void initState() {
    super.initState();
    _server.addListener(_onServerChanged);
    _dm.addListener(_onServerChanged); // progreso de la mejora en vivo
    _prepareModel();
  }

  @override
  void dispose() {
    _server.removeListener(_onServerChanged);
    _dm.removeListener(_onServerChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onServerChanged() {
    if (!mounted) return;
    // ¿Terminó la descarga de mejora mientras chateamos en modo ligero?
    // Recargar con el modelo completo (fuera de build, aquí es seguro).
    final status = _status;
    if (status != null && status.usingLiteFallback) {
      final main = _modelFor(widget.agent);
      if (_installedModelFileNames().contains(main.fileName)) {
        _status = null;
        _loadingModel = true;
        _prepareModel();
      }
    }
    setState(() {});
  }

  /// Resolve the effective model (RAM guard may pick the lite fallback) and
  /// load it. If the model is not installed, the chat stays disabled and the
  /// header explains why — the grid is where installs are started.
  Future<void> _prepareModel() async {
    final freeRam = await AiEngine.freeRamBytes();
    // Modelo activo GLOBAL: la elección del usuario (o el mejor instalado por
    // defecto — Gemma 4 sembrado). Lo comparten chat general y especialistas.
    final active = resolveActiveModel(
      installed: _installedModelFileNames().toList(),
      chosen: NuvokLibrary.instance.settings['aiActiveModelFile'] as String?,
      freeRamBytes: freeRam,
    );
    // Estado por-clase, solo para el banner de mejora del especialista.
    final status = AgentRuntime.resolve(
      model: _modelFor(widget.agent),
      installedFileNames: _installedModelFileNames(),
      freeRamBytes: freeRam,
    );
    if (!mounted) return;
    _status = status;
    _activeFile = active;
    if (active != null) {
      await _server.start('${NuvokLibrary.instance.modelsDir.path}/$active');
    }
    if (mounted) setState(() => _loadingModel = false);
  }

  /// Fija el modelo activo global y recarga el motor con él.
  Future<void> _selectModel(String fileName) async {
    await NuvokLibrary.instance.saveSetting('aiActiveModelFile', fileName);
    if (!mounted) return;
    setState(() {
      _loadingModel = true;
      _activeFile = fileName;
    });
    await _server.stop();
    await _prepareModel();
  }

  /// Hoja inferior para elegir el modelo activo entre los instalados, con
  /// atajo a Depósito para descargar más.
  void _openModelPicker() {
    final installed = _installedModelFileNames().toList()..sort();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(tr(sheetCtx, 'modelPickTitle'),
                  style: Theme.of(sheetCtx).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Text(tr(sheetCtx, 'modelPickSubtitle'),
                  style: Theme.of(sheetCtx).textTheme.bodySmall),
            ),
            for (final f in installed)
              ListTile(
                leading: Icon(f == _activeFile
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(modelDisplayName(f)),
                trailing: f == _activeFile
                    ? Text(tr(sheetCtx, 'modelPickActive'),
                        style: TextStyle(
                            color: Theme.of(sheetCtx).colorScheme.primary))
                    : null,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  if (f != _activeFile) _selectModel(f);
                },
              ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(tr(sheetCtx, 'modelPickDownloadMore')),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const DepotPage(initialTab: 2),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Banner de mejora: visible mientras el chat corre en el modelo ligero.
  /// Ofrece descargar el especialista completo y muestra el progreso; al
  /// terminar la descarga, _prepareModel recarga con el modelo bueno.
  Widget? _upgradeBanner(BuildContext context) {
    final status = _status;
    if (status == null || !status.usingLiteFallback) return null;
    final main = _modelFor(widget.agent);
    final task = _dm.taskFor(main.url);
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: task != null
            ? Row(children: [
                Expanded(
                    child: LinearProgressIndicator(value: task.progress)),
                const SizedBox(width: 8),
                Text(
                    task.progress == null
                        ? '…'
                        : '${(task.progress! * 100).round()}%',
                    style: const TextStyle(fontSize: 12)),
              ])
            : Row(children: [
                Expanded(
                  child: Text(tr(context, 'agentLiteBanner'),
                      style: const TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => _dm.enqueue(
                    main.url,
                    '${NuvokLibrary.instance.modelsDir.path}/${main.fileName}',
                    totalBytes: main.sizeBytes,
                    sha256Hex: main.sha256 == 'TO_FILL_ON_UPLOAD'
                        ? null
                        : main.sha256,
                  ),
                  child: Text(tr(context, 'agentUpgrade')),
                ),
              ]),
      ),
    );
  }

  /// Builds the grounding-aware system prompt for this agent in the language
  /// the QUESTION was written in (app language as fallback), so a Spanish
  /// question gets a Spanish answer even on a phone set to English. Reuses
  /// the emergency/library retrievers already in the app.
  Future<(String, List<RetrievedSource>)> _buildContext(String text) async {
    final lang = detectReplyLang(text,
        appLang: LocaleService.instance.language.code);
    final mode = SurvivalModeStore.active == SurvivalMode.none
        ? null
        : SurvivalModeStore.active.name;
    var systemPrompt = widget.agent.system(lang);
    List<RetrievedSource> sources = const [];

    switch (widget.agent.grounding) {
      case GroundingMode.guidesFirst:
        try {
          sources =
              await EmergencyRetriever.retrieve(text, lang: lang, mode: mode);
        } catch (_) {}
        // Compuerta de relevancia: los retrievers devuelven "lo menos malo"
        // para cualquier texto. Si las fuentes no tocan la pregunta (pediste
        // código, una carta, matemáticas), el especialista responde con su
        // conocimiento pleno en vez de recibir guías ajenas con reglas de
        // citado que degradan la respuesta.
        if (!LibraryRetriever.sourcesLookRelevant(text, sources)) {
          sources = const [];
        }
        if (sources.isNotEmpty) {
          // La persona (systemPrompt) se conserva; las fuentes se SUMAN.
          systemPrompt = composeAgentPrompt(
            systemPrompt,
            EmergencyRetriever.buildEmergencyContext(sources,
                replyLang: lang, mode: mode),
          );
        }
      case GroundingMode.library:
        if (NuvokLibrary.instance.listZims().isNotEmpty) {
          try {
            sources = await LibraryRetriever.retrieve(text);
          } catch (_) {}
          if (!LibraryRetriever.sourcesLookRelevant(text, sources)) {
            sources = const [];
          }
          if (sources.isNotEmpty) {
            systemPrompt = composeAgentPrompt(
              systemPrompt,
              LibraryRetriever.buildSourcesBlock(sources, replyLang: lang),
            );
          }
        }
      case GroundingMode.none:
        break;
    }
    return (systemPrompt, sources);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _generating) return;
    _input.clear();

    // Psychologist guardrail: on crisis language, lead with the SOS notice
    // and never bury it under generated text.
    final crisis =
        widget.agent.crisisGuardrails && AgentRuntime.looksLikeCrisis(text);

    setState(() {
      _messages.add(ChatMessage('user', text));
      _messages.add(ChatMessage('assistant',
          crisis ? '🆘 ${tr(context, 'agentCrisisNotice')}\n\n' : ''));
      _generating = true;
    });
    _scrollToEnd();

    if (_hasGrounding) {
      setState(() => _messages.last.text +=
          '🔎 ${tr(context, 'aiSearchingLibrary')}');
    }
    final (systemPrompt, sources) = await _buildContext(text);
    if (!mounted) return;
    setState(() {
      _messages.last
        ..text = crisis ? '🆘 ${tr(context, 'agentCrisisNotice')}\n\n' : ''
        ..sources = sources;
    });

    // Reply in the language of the question, not of the phone's UI.
    final lang = detectReplyLang(text,
        appLang: LocaleService.instance.language.code);
    final reminder = LibraryRetriever.languageReminder(lang);
    try {
      final visible = _messages
          .where((m) => m.role == 'user' || m.text.isNotEmpty)
          .toList();
      final current = visible.last; // the just-sent question
      final history = [
        {'role': 'system', 'content': systemPrompt},
        for (final m in visible)
          if (m.role == 'user')
            {
              'role': 'user',
              'content':
                  identical(m, current) ? '${m.text}\n\n$reminder' : m.text,
            }
          else
            {'role': m.role, 'content': m.text},
      ];
      await for (final token
          in _server.chat(history, temp: widget.agent.temperature)) {
        setState(() => _messages.last.text += token);
        _scrollToEnd();
      }
    } catch (e) {
      // Guides-first agents stay useful with no model: answer from the guide.
      if (widget.agent.grounding == GroundingMode.guidesFirst) {
        final strict = await EmergencyRetriever.strictAnswer(
          text,
          appLang: lang,
          mode: SurvivalModeStore.active == SurvivalMode.none
              ? null
              : SurvivalModeStore.active.name,
        );
        setState(() {
          _messages.last.text = strict ?? '⚠️ $e';
        });
      } else {
        setState(() {
          _messages.last.text =
              _messages.last.text.isEmpty ? '⚠️ $e' : _messages.last.text;
        });
      }
    } finally {
      setState(() => _generating = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final lang = LocaleService.instance.language.code;
    final running = _server.status == LlamaStatus.running;
    // Guides-first agents (Vera, Norte, Elías) answer from the guides even
    // with no model, so their input stays enabled.
    final canType =
        running || agent.grounding == GroundingMode.guidesFirst;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: agent.accent,
              child: Icon(agent.avatar, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(agent.nameProper,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(agent.role(lang),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
        actions: [
          if (_activeFile != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.memory, size: 16),
                label: Text(modelDisplayName(_activeFile!),
                    overflow: TextOverflow.ellipsis),
                onPressed: _openModelPicker,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingModel) const LinearProgressIndicator(),
          if (_upgradeBanner(context) case final banner?) banner,
          if (_server.status == LlamaStatus.error &&
              _server.lastError != null)
            MaterialBanner(
              content: Text(_server.lastError!),
              leading: const Icon(Icons.error_outline),
              actions: [
                TextButton(
                  onPressed: () => _server.stop(),
                  child: Text(tr(context, 'discard')),
                ),
              ],
            ),
          Expanded(
            child: _messages.isEmpty
                ? _AgentIntro(agent: agent, running: running)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _Bubble(message: _messages[i]),
                  ),
          ),
          if (agent.quickChipKeys.isNotEmpty && !_generating)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final key in agent.quickChipKeys)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: Icon(agent.avatar, size: 16, color: agent.accent),
                        label: Text(_chipLabel(context, key)),
                        onPressed: () {
                          _input.text = _chipLabel(context, key);
                          _send();
                        },
                      ),
                    ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: canType,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: running
                            ? tr(context, 'aiHintAsk')
                            : (agent.grounding == GroundingMode.guidesFirst
                                ? tr(context, 'aiHintEmergency')
                                : tr(context, 'aiHintLoad')),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _generating ? null : _send,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Quick-chip labels reuse existing i18n; the survival-mode chips fill in
  /// the active environment name like the old emergency quick actions did.
  String _chipLabel(BuildContext context, String key) {
    final raw = tr(context, key);
    if (raw.contains('{mode}')) {
      return raw.replaceFirst(
          '{mode}', tr(context, SurvivalModeStore.active.nameKey));
    }
    return raw;
  }
}

/// Intro shown before the first message: who the agent is + engine status.
class _AgentIntro extends StatelessWidget {
  const _AgentIntro({required this.agent, required this.running});
  final AgentSpec agent;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleService.instance.language.code;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: agent.accent,
                    child: Icon(agent.avatar, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(agent.nameProper,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(agent.role(lang),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    running
                        ? tr(context, 'aiHintAsk')
                        : tr(context, 'aiEmptyHint'),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty-state card shown when a model is present but not yet loaded. Kept for
/// the manual-model flow (Settings → advanced) and back-compat tests.
class AiEmptyState extends StatelessWidget {
  const AiEmptyState(
      {super.key, required this.selectedModelPath, required this.server});

  final String? selectedModelPath;
  final AiEngine server;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final modelName = selectedModelPath == null
        ? tr(context, 'aiNoModelSelected')
        : File(selectedModelPath!).uri.pathSegments.last;
    final status = switch (server.status) {
      LlamaStatus.stopped => tr(context, 'aiStatusStopped'),
      LlamaStatus.starting => tr(context, 'aiStatusStarting'),
      LlamaStatus.running => tr(context, 'aiStatusReady'),
      LlamaStatus.error => server.lastError ?? tr(context, 'aiStatusError'),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_alt_outlined,
                    size: 56,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(context, 'aiModelFound'),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    modelName,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(context, 'aiEmptyHint'),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 640),
            decoration: BoxDecoration(
              color: isUser
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(message.text.isEmpty ? '…' : message.text),
          ),
          if (message.sources.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxWidth: 640),
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(tr(context, 'aiSources'),
                        style: Theme.of(context).textTheme.labelSmall),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < message.sources.length; i++)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: CircleAvatar(
                            backgroundColor: scheme.primary,
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 11, color: scheme.onPrimary)),
                          ),
                          label: Text(
                            '${message.sources[i].title} · '
                            '${message.sources[i].book}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
