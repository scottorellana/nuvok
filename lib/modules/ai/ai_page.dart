import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/prepper_library.dart';
import 'emergency_retriever.dart';
import 'library_retriever.dart';
import 'ai_engine.dart';
import 'llama_server.dart' show LlamaStatus;
import '../../core/locale_service.dart';

class ChatMessage {
  ChatMessage(this.role, this.text, {this.sources = const []});
  final String role; // 'user' | 'assistant'
  String text;
  List<RetrievedSource> sources;
}

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final _server = AiEngine.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  List<File> _models = [];
  String? _selectedModel;
  bool _generating = false;
  bool _useLibrary = true; // ground answers in the offline library
  bool _emergencyMode = false; // guides-first grounding + strict fallback

  @override
  void initState() {
    super.initState();
    _server.addListener(_onServerChanged);
    _refreshModels();
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

  void _refreshModels() {
    setState(() {
      _models = PrepperLibrary.instance.listModels();
      if (_models.isNotEmpty &&
          (_selectedModel == null ||
              !_models.any((m) => m.path == _selectedModel))) {
        _selectedModel = _models.first.path;
      }
    });
  }

  Future<void> _loadModel() async {
    final path = _selectedModel;
    if (path == null) return;
    final size = File(path).lengthSync();
    final free = await AiEngine.freeRamBytes();
    if (!mounted) return;
    if (free != null && size > free * 0.8) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(context, 'tightMemory')),
          content: Text(tr(context, 'aiRamWarn')
              .replaceFirst('{size}', humanSize(size))
              .replaceFirst('{free}', humanSize(free))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'loadAnyway')),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await _server.start(path);
  }

  /// System prompt in the app's active language. Small models follow an
  /// explicit language instruction far better than "reply in the user's
  /// language", so each UI language pins the reply language too.
  String _systemPromptForLanguage() {
    const prompts = {
      'es': 'Eres el asistente de Prepper Pad, una app de conocimiento '
          'offline. Responde de forma útil y concisa, siempre en español.',
      'en': 'You are the Prepper Pad assistant, an offline knowledge app. '
          'Reply helpfully and concisely, always in English.',
      'pt': 'Você é o assistente do Prepper Pad, um app de conhecimento '
          'offline. Responda de forma útil e concisa, sempre em português.',
      'fr': 'Tu es l\'assistant de Prepper Pad, une app de connaissances '
          'hors ligne. Réponds utilement et brièvement, toujours en français.',
      'zh': '你是 Prepper Pad 的助手，一款离线知识应用。请始终用中文简明有用地回答。',
      'ja': 'あなたはオフライン知識アプリ Prepper Pad のアシスタントです。'
          '常に日本語で簡潔かつ役立つ回答をしてください。',
      'ht': 'Ou se asistan Prepper Pad, yon aplikasyon konesans san entènèt. '
          'Reponn yon fason itil e kout, toujou an kreyòl.',
    };
    final code = LocaleService.instance.language.code;
    return prompts[code] ?? prompts['en']!;
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _generating) return;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage('user', text));
      _messages.add(ChatMessage('assistant', ''));
      _generating = true;
    });
    _scrollToEnd();

    // When grounding is on, retrieve evidence from the installed ZIMs and
    // build a system prompt that lists those sources and requires citations.
    // Emergency mode retrieves from the bundled guides FIRST.
    List<RetrievedSource> sources = const [];
    String systemPrompt = _systemPromptForLanguage();
    if (_emergencyMode) {
      setState(() =>
          _messages.last.text = '🚨 ${tr(context, 'aiSearchingGuides')}');
      try {
        sources = await EmergencyRetriever.retrieve(text);
      } catch (_) {}
      if (sources.isNotEmpty) {
        systemPrompt = EmergencyRetriever.buildEmergencySystemPrompt(sources);
      }
      if (mounted) {
        setState(() {
          _messages.last
            ..text = ''
            ..sources = sources;
        });
      }
    } else if (_useLibrary && PrepperLibrary.instance.listZims().isNotEmpty) {
      setState(() =>
          _messages.last.text = '🔎 ${tr(context, 'aiSearchingLibrary')}');
      try {
        sources = await LibraryRetriever.retrieve(text);
      } catch (_) {}
      if (sources.isNotEmpty) {
        systemPrompt = LibraryRetriever.buildGroundedSystemPrompt(sources);
      }
      if (mounted) {
        setState(() {
          _messages.last
            ..text = ''
            ..sources = sources;
        });
      }
    }

    try {
      final history = [
        {'role': 'system', 'content': systemPrompt},
        for (final m
            in _messages.where((m) => m.role == 'user' || m.text.isNotEmpty))
          {'role': m.role, 'content': m.text},
      ];
      await for (final token in _server.chat(history)) {
        setState(() => _messages.last.text += token);
        _scrollToEnd();
      }
      // A model that answered nothing helps nobody in an emergency: fall
      // back to the raw guide.
      if (_emergencyMode && _messages.last.text.trim().isEmpty) {
        final strict = await EmergencyRetriever.strictAnswer(text);
        if (strict != null) setState(() => _messages.last.text = strict);
      }
    } catch (e) {
      // No local model (Android today) or it crashed: in emergency mode the
      // guides answer directly — no generation, no hallucination, no delay.
      if (_emergencyMode) {
        final strict = await EmergencyRetriever.strictAnswer(text);
        setState(() {
          _messages.last.text =
              strict ?? '⚠️ ${tr(context, 'aiNoAiNoGuide')} ($e)';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'assistant')),
        actions: [
          Row(
            children: [
              Icon(Icons.emergency,
                  size: 18, color: _emergencyMode ? Colors.red : null),
              const SizedBox(width: 4),
              Text(tr(context, 'emergency'),
                  style: TextStyle(
                      color: _emergencyMode ? Colors.red : null,
                      fontWeight: _emergencyMode ? FontWeight.bold : null)),
              Switch(
                value: _emergencyMode,
                activeTrackColor: Colors.red,
                onChanged: (v) => setState(() => _emergencyMode = v),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.menu_book_outlined, size: 18),
              const SizedBox(width: 4),
              Text(tr(context, 'library')),
              Switch(
                value: _useLibrary,
                onChanged: (v) => setState(() => _useLibrary = v),
              ),
            ],
          ),
          IconButton(
            tooltip: tr(context, 'aiRefreshModels'),
            icon: const Icon(Icons.refresh),
            onPressed: _refreshModels,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_selectedModel),
                    initialValue: _selectedModel,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'model'),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final m in _models)
                        DropdownMenuItem(
                          value: m.path,
                          child: Text(
                            '${m.uri.pathSegments.last} '
                            '(${humanSize(m.lengthSync())})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _selectedModel = v),
                  ),
                ),
                const SizedBox(width: 12),
                _ServerButton(server: _server, onLoad: _loadModel),
              ],
            ),
          ),
        ),
      ),
      body: _models.isEmpty
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  '${tr(context, 'aiNoModels')}\n'
                  '${PrepperLibrary.instance.modelsDir.path}',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
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
                      ? AiEmptyState(
                          selectedModelPath: _selectedModel,
                          server: _server,
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) => _Bubble(message: _messages[i]),
                        ),
                ),
                // En pánico nadie redacta: un toque envía la pregunta
                // crítica ya escrita en el idioma de la app.
                if (_emergencyMode && !_generating)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final key in const [
                          'aiQuickRcp',
                          'aiQuickChoking',
                          'aiQuickBleeding',
                          'aiQuickBurn',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.emergency,
                                  size: 16, color: Colors.red),
                              label: Text(tr(context, key)),
                              onPressed: () {
                                _input.text = tr(context, key);
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
                            enabled: _server.status == LlamaStatus.running ||
                                _emergencyMode,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: _server.status == LlamaStatus.running
                                  ? tr(context, 'aiHintAsk')
                                  : _emergencyMode
                                      ? tr(context, 'aiHintEmergency')
                                      : tr(context, 'aiHintLoad'),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
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
}

class AiEmptyState extends StatelessWidget {
  const AiEmptyState({super.key, required this.selectedModelPath, required this.server});

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

class _ServerButton extends StatelessWidget {
  const _ServerButton({required this.server, required this.onLoad});
  final AiEngine server;
  final Future<void> Function() onLoad;

  @override
  Widget build(BuildContext context) {
    switch (server.status) {
      case LlamaStatus.stopped:
      case LlamaStatus.error:
        return FilledButton.icon(
          onPressed: onLoad,
          icon: const Icon(Icons.play_arrow),
          label: Text(tr(context, 'load')),
        );
      case LlamaStatus.starting:
        return const FilledButton(
          onPressed: null,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case LlamaStatus.running:
        return OutlinedButton.icon(
          onPressed: () => server.stop(),
          icon: const Icon(Icons.stop),
          label: Text(tr(context, 'stop')),
        );
    }
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
