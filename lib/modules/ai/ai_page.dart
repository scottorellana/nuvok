import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/prepper_library.dart';
import 'emergency_retriever.dart';
import 'library_retriever.dart';
import 'llama_server.dart';

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
  final _server = LlamaServer.instance;
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
    final free = await LlamaServer.freeRamBytes();
    if (!mounted) return;
    if (free != null && size > free * 0.8) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Memoria ajustada'),
          content: Text(
            'Este modelo pesa ${humanSize(size)} y tu memoria libre '
            'aproximada es ${humanSize(free)}. Cargarlo puede hacer lenta '
            'la máquina. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cargar igual'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await _server.start(path);
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
    String systemPrompt =
        'Eres el asistente de Prepper Pad, una app de conocimiento offline. '
        'Responde de forma útil y concisa en el idioma del usuario.';
    if (_emergencyMode) {
      setState(() => _messages.last.text = '🚨 Buscando en las guías…');
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
      setState(() => _messages.last.text = '🔎 Buscando en la biblioteca…');
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
          _messages.last.text = strict ??
              '⚠️ Sin IA local y sin guía que coincida. Abre la pestaña '
                  'Emergencia y busca ahí. ($e)';
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
        title: const Text('Asistente IA'),
        actions: [
          Row(
            children: [
              Icon(Icons.emergency,
                  size: 18, color: _emergencyMode ? Colors.red : null),
              const SizedBox(width: 4),
              Text('Emergencia',
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
              const Text('Biblioteca'),
              Switch(
                value: _useLibrary,
                onChanged: (v) => setState(() => _useLibrary = v),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Actualizar modelos',
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
                    decoration: const InputDecoration(
                      labelText: 'Modelo',
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
                  'No hay modelos de IA todavía.\n\nDescarga uno desde el '
                  'Depósito o copia un archivo .gguf a:\n'
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
                        child: const Text('Descartar'),
                      ),
                    ],
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _Bubble(message: _messages[i]),
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
                            enabled: _server.status == LlamaStatus.running,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: _server.status == LlamaStatus.running
                                  ? 'Escribe tu pregunta…'
                                  : 'Carga un modelo para chatear',
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

class _ServerButton extends StatelessWidget {
  const _ServerButton({required this.server, required this.onLoad});
  final LlamaServer server;
  final Future<void> Function() onLoad;

  @override
  Widget build(BuildContext context) {
    switch (server.status) {
      case LlamaStatus.stopped:
      case LlamaStatus.error:
        return FilledButton.icon(
          onPressed: onLoad,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Cargar'),
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
          label: const Text('Detener'),
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
                    child: Text('Fuentes de la biblioteca:',
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
