// "Comunicación": offline chat over the local mesh. Channels secured with a
// shared key (QR / code), the always-open EMERGENCIA channel, a big SOS
// button, and position sharing toward the Maps module.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'mesh_channel.dart';
import 'mesh_envelope.dart';
import 'mesh_router.dart';
import 'mesh_service.dart';

class MeshPage extends StatefulWidget {
  const MeshPage({super.key});

  @override
  State<MeshPage> createState() => _MeshPageState();
}

class _MeshPageState extends State<MeshPage> {
  final _service = MeshService.instance;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_service.hasIdentity && !_service.running.value) {
      _service.start().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await _service.setIdentity(name);
    if (mounted) setState(() {});
  }

  Future<void> _createChannel() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear canal'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Nombre del grupo (ej. Familia)'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, nameCtrl.text),
              child: const Text('Crear')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final channel = MeshChannel.create(name.trim());
    await _service.joinChannel(channel);
    if (mounted) {
      setState(() {});
      _showChannelCode(channel);
    }
  }

  /// QR + copyable code so other devices can join this channel.
  void _showChannelCode(MeshChannel channel) {
    final code = channel.toCode();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Canal "${channel.name}"'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: code, size: 220),
              ),
              const SizedBox(height: 12),
              const Text('En el otro dispositivo: Comunicación → Unirse '
                  'y pega este código (o escanea el QR cuando tengas '
                  'lector).'),
              const SizedBox(height: 8),
              SelectableText(code,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código copiado')));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar código'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo')),
        ],
      ),
    );
  }

  Future<void> _joinChannel() async {
    final codeCtrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unirse a un canal'),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Pega el código PPMESH1:…',
            hintText: 'Pídelo al que creó el canal',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, codeCtrl.text),
              child: const Text('Unirme')),
        ],
      ),
    );
    if (code == null || !mounted) return;
    final channel = MeshChannel.fromCode(code.trim());
    if (channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Código inválido — revisa que esté completo.')));
      return;
    }
    await _service.joinChannel(channel);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unido a "${channel.name}"')));
    }
  }

  Future<void> _confirmSos() async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sos, color: Colors.red, size: 40),
        title: const Text('¿Activar SOS?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tu posición y esta nota se difundirán cada minuto a '
                'TODOS los Prepper Pad al alcance (no solo tu grupo), hasta '
                'que lo canceles.'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nota (opcional): ¿qué pasa?'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ACTIVAR SOS'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.startSos(note: noteCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.hasIdentity) return _buildOnboarding(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunicación (sin internet)'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _service.peerCount,
            builder: (context, count, _) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: Icon(Icons.podcasts,
                    size: 18,
                    color: count > 0 ? Colors.greenAccent : Colors.grey),
                label: Text(count > 0
                    ? '$count cerca'
                    : 'buscando dispositivos…'),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSosCard(),
          const SizedBox(height: 12),
          _buildStatusRow(),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Canales', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                  onPressed: _joinChannel,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Unirse')),
              const SizedBox(width: 4),
              FilledButton.icon(
                  onPressed: _createChannel,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Crear')),
            ],
          ),
          const SizedBox(height: 4),
          _channelTile(MeshChannel.emergency,
              subtitle: 'Abierto a todos los dispositivos cercanos'),
          for (final c in _service.channels)
            _channelTile(c, showCode: true),
          if (_service.channels.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Crea un canal para tu familia o grupo y compártelo por '
                'código QR. Los mensajes van cifrados: solo quien tiene el '
                'código puede leerlos.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOnboarding(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicación (sin internet)')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cell_tower,
                      size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Prepper Mesh',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Chatea, comparte tu posición y lanza SOS entre '
                    'dispositivos cercanos SIN internet (misma red WiFi o '
                    'hotspot). ¿Cómo quieres que te vean los demás?',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de este dispositivo',
                      hintText: 'ej. Tablet de Ana',
                    ),
                    onSubmitted: (_) => _saveName(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saveName,
                    icon: const Icon(Icons.check),
                    label: const Text('Empezar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSosCard() {
    return ValueListenableBuilder(
      valueListenable: _service.sosActive,
      builder: (context, active, _) {
        if (active) {
          return Card(
            color: Colors.red.shade900,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sos, color: Colors.white, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'SOS ACTIVO — difundiendo tu posición cada minuto '
                          'a todos los dispositivos al alcance.',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.white,
                            foregroundColor: Colors.red.shade900),
                    onPressed: () => _service.cancelSos(),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('ESTOY A SALVO (cancelar SOS)'),
                  ),
                ],
              ),
            ),
          );
        }
        return Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.red,
              radius: 26,
              child: const Icon(Icons.sos, color: Colors.white, size: 30),
            ),
            title: const Text('Emergencia — pedir ayuda'),
            subtitle: const Text(
                'Difunde tu posición a TODO dispositivo cercano, sin claves'),
            trailing: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _confirmSos,
              child: const Text('SOS'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        ValueListenableBuilder(
          valueListenable: _service.queuedCount,
          builder: (context, queued, _) => queued == 0
              ? const SizedBox.shrink()
              : Chip(
                  avatar: const Icon(Icons.schedule_send, size: 18),
                  label: Text('$queued en cola (sin alcance)'),
                ),
        ),
        const Spacer(),
        const Text('Compartir mi posición'),
        ValueListenableBuilder(
          valueListenable: _service.sharingPosition,
          builder: (context, sharing, _) => Switch(
            value: sharing,
            onChanged: (v) => _service.setSharePosition(v),
          ),
        ),
      ],
    );
  }

  Widget _channelTile(MeshChannel channel,
      {String? subtitle, bool showCode = false}) {
    final last = _service.store.loadMessages(channel.id, limit: 1);
    final preview = last.isEmpty
        ? (subtitle ?? 'Sin mensajes todavía')
        : '${last.last['_name']}: ${last.last['text'] ?? '…'}';
    final isEmergency = channel.isEmergency;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isEmergency ? Colors.red.shade900 : Colors.blueGrey.shade700,
          child: Icon(isEmergency ? Icons.campaign : Icons.forum,
              color: Colors.white, size: 20),
        ),
        title: Text(isEmergency ? 'EMERGENCIA (todos)' : channel.name),
        subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCode)
              IconButton(
                tooltip: 'Mostrar código / QR para invitar',
                icon: const Icon(Icons.qr_code),
                onPressed: () => _showChannelCode(channel),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => _ChatPage(channel: channel)));
          if (mounted) setState(() {}); // refresh previews
        },
      ),
    );
  }
}

class _ChatPage extends StatefulWidget {
  const _ChatPage({required this.channel});
  final MeshChannel channel;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final _service = MeshService.instance;
  final _inputCtrl = TextEditingController();
  final _scroll = ScrollController();
  late List<Map<String, dynamic>> _messages;
  StreamSubscription<MeshEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _messages = _service.store.loadMessages(widget.channel.id);
    _sub = _service.events.listen((e) {
      if (e.channel.id != widget.channel.id) return;
      if (e.envelope.type != MeshType.chat &&
          e.envelope.type != MeshType.sos) {
        return;
      }
      setState(() {
        _messages.add({
          ...e.payload,
          '_from': e.envelope.senderId,
          '_name': e.envelope.senderName,
          '_type': e.envelope.type.name,
          '_ts': e.envelope.timestampMs,
        });
      });
      _scrollToEnd();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inputCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await _service.sendChat(widget.channel, text);
    // Local echo arrives via the events stream; nothing else to do.
  }

  @override
  Widget build(BuildContext context) {
    final myId = _service.identity?.id;
    final isEmergency = widget.channel.isEmergency;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEmergency
            ? 'EMERGENCIA (todos los cercanos)'
            : widget.channel.name),
        backgroundColor: isEmergency ? Colors.red.shade900 : null,
      ),
      body: Column(
        children: [
          if (isEmergency)
            Container(
              width: double.infinity,
              color: Colors.red.shade900.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Canal abierto SIN cifrar: lo lee cualquier Prepper Pad '
                'cercano. Úsalo para pedir o dar ayuda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _service.peerCount,
              builder: (context, count, _) => _messages.isEmpty
                  ? Center(
                      child: Text(
                        count > 0
                            ? 'Sin mensajes. ¡Escribe el primero!'
                            : 'Sin dispositivos al alcance.\nLos mensajes '
                                'que envíes quedarán en cola y se '
                                'entregarán cuando alguien aparezca.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final mine = m['_from'] == myId;
                        final isSos = m['_type'] == 'sos';
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            constraints: const BoxConstraints(maxWidth: 420),
                            decoration: BoxDecoration(
                              color: isSos
                                  ? Colors.red.shade900
                                  : mine
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine)
                                  Text(m['_name'] as String? ?? '?',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)),
                                Text(isSos
                                    ? '🆘 SOS ${m['note'] ?? ''} '
                                        '(${m['lat']?.toStringAsFixed(4)}, '
                                        '${m['lon']?.toStringAsFixed(4)})'
                                    : m['text'] as String? ?? ''),
                                Text(
                                  _fmtTime(m['_ts'] as int?),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: InputDecoration(
                        hintText: isEmergency
                            ? 'Mensaje para TODOS los cercanos…'
                            : 'Mensaje…',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(int? ms) {
    if (ms == null) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }
}
