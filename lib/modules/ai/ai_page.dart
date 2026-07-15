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
import 'reply_lang.dart';

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
Set<String> _installedModelFileNames() =>
    NuvokLibrary.instance.listModels().map((f) => f.uri.pathSegments.last).toSet();

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
    final m = ModelCatalog.byId(agent.modelId);
    if (m == null) return;
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
    final model = ModelCatalog.byId(agent.modelId)!;
    return AgentRuntime.resolve(
      model: model,
      installedFileNames: installed,
      freeRamBytes: freeRam,
    );
  }

  /// Active download progress (0..1) for this agent's model, or null.
  double? _progressFor(AgentSpec agent) {
    final m = ModelCatalog.byId(agent.modelId);
    if (m == null) return null;
    final task = _dm.taskFor(m.url);
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
              Text(agent.role(lang),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              if (downloading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: LinearProgressIndicator(value: downloadProgress),
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
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _generating = false;
  bool _loadingModel = true;

  bool get _hasGrounding => widget.agent.grounding != GroundingMode.none;

  @override
  void initState() {
    super.initState();
    _server.addListener(_onServerChanged);
    _prepareModel();
  }

  @override
  void dispose() {
    _server.removeListener(_onServerChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onServerChanged() {
    if (mounted) setState(() {});
  }

  /// Resolve the effective model (RAM guard may pick the lite fallback) and
  /// load it. If the model is not installed, the chat stays disabled and the
  /// header explains why — the grid is where installs are started.
  Future<void> _prepareModel() async {
    final model = ModelCatalog.byId(widget.agent.modelId);
    if (model == null) {
      setState(() => _loadingModel = false);
      return;
    }
    final status = AgentRuntime.resolve(
      model: model,
      installedFileNames: _installedModelFileNames(),
      freeRamBytes: await AiEngine.freeRamBytes(),
    );
    if (!mounted) return;
    if (status.state == AgentInstallState.ready) {
      final path =
          '${NuvokLibrary.instance.modelsDir.path}/${status.effectiveModel.fileName}';
      await _server.start(path);
    }
    if (mounted) setState(() => _loadingModel = false);
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
        if (sources.isNotEmpty) {
          systemPrompt = EmergencyRetriever.buildEmergencySystemPrompt(
            sources,
            replyLang: lang,
            mode: mode,
          );
        }
      case GroundingMode.library:
        if (NuvokLibrary.instance.listZims().isNotEmpty) {
          try {
            sources = await LibraryRetriever.retrieve(text);
          } catch (_) {}
          if (sources.isNotEmpty) {
            systemPrompt = LibraryRetriever.buildGroundedSystemPrompt(
              sources,
              replyLang: lang,
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
      await for (final token in _server.chat(history)) {
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
      ),
      body: Column(
        children: [
          if (_loadingModel) const LinearProgressIndicator(),
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
