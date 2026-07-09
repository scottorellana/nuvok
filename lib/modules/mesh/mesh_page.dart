// "Comunicación": offline chat over the local mesh. Channels secured with a
// shared key (QR / code), the always-open EMERGENCIA channel, a big SOS
// button, and position sharing toward the Maps module.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/locale_service.dart';
import 'connection_banner.dart';
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
  // Cuándo empezó la sesión de búsqueda ACTUAL — el asistente escala sus
  // consejos (hotspot, LoRa) según cuánto llevamos sin encontrar a nadie.
  // Se reancla cuando los pares caen a cero: si no, tras una hora conectado
  // una desconexión saltaría directo a hotspot sin dar tiempo a reconectar.
  DateTime _searchStart = DateTime.now();
  int _lastPeerCount = 0;

  void _onPeerCountChange() {
    final c = _service.peerCount.value;
    if (_lastPeerCount > 0 && c == 0) _searchStart = DateTime.now();
    _lastPeerCount = c;
  }

  @override
  void initState() {
    super.initState();
    _lastPeerCount = _service.peerCount.value;
    _service.peerCount.addListener(_onPeerCountChange);
    if (_service.hasIdentity && !_service.running.value) {
      _service.start().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _service.peerCount.removeListener(_onPeerCountChange);
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
        title: Text(tr(context, 'createChannel')),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
              labelText: tr(context, 'groupNameHint')),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, nameCtrl.text),
              child: Text(tr(context, 'create'))),
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
    final codeDialogWidth =
        (MediaQuery.of(context).size.width - 48).clamp(280.0, 420.0).toDouble();
    final qrSize = (codeDialogWidth - 64).clamp(140.0, 260.0).toDouble();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${tr(context, 'channelWord')} "${channel.name}"'),
        content: SizedBox(
          width: codeDialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: code, size: qrSize),
              ),
              const SizedBox(height: 12),
              Text(tr(context, 'joinInstructions')),
              const SizedBox(height: 8),
              SelectableText(code,
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                  maxLines: 4),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr(context, 'codeCopied'))));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text(tr(context, 'copyCode')),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'done'))),
        ],
      ),
    );
  }

  Future<void> _joinChannel() async {
    final codeCtrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'joinChannel')),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: tr(context, 'pasteCodeHint'),
            hintText: tr(context, 'askCreator'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, codeCtrl.text),
              child: Text(tr(context, 'join'))),
        ],
      ),
    );
    if (code == null || !mounted) return;
    final channel = MeshChannel.fromCode(code.trim());
    if (channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(context, 'invalidCode'))));
      return;
    }
    await _service.joinChannel(channel);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${tr(context, 'joinedChannel')} "${channel.name}"')));
    }
  }

  Future<void> _confirmSos() async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sos, color: Colors.red, size: 40),
        title: Text(tr(context, 'activateSosQ')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr(context, 'sosBody')),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                  labelText: tr(context, 'sosNoteHint')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'activateSos')),
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
        title: Text(tr(context, 'meshTitle')),
        actions: [
          ValueListenableBuilder(
            valueListenable: _service.peerCount,
            builder: (context, count, _) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: Icon(Icons.podcasts,
                    size: 18,
                    color: count > 0 ? Colors.greenAccent : Colors.grey),
                label:
                    Text(count > 0 ? '$count ${tr(context, 'nearby')}' : tr(context, 'searchingDevices')),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de salud del mesh: verde con pares (y por qué transporte),
          // ámbar buscando — tocar abre el Asistente de conexión.
          AnimatedBuilder(
            animation: Listenable.merge(
                [_service.transportHealths, _service.peerCount]),
            builder: (context, _) => ConnectionBanner(
              healths: _service.transportHealths.value,
              totalPeers: _service.peerCount.value,
              searchStart: _searchStart,
            ),
          ),
          Expanded(child: _buildMainList(context)),
        ],
      ),
    );
  }

  Widget _buildMainList(BuildContext context) {
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSosCard(),
          const SizedBox(height: 12),
          _buildStatusRow(),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(tr(context, 'channels'), style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                  onPressed: _joinChannel,
                  icon: const Icon(Icons.input, size: 18),
                  label: Text(tr(context, 'join'))),
              const SizedBox(width: 4),
              FilledButton.icon(
                  onPressed: _createChannel,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr(context, 'create'))),
            ],
          ),
          const SizedBox(height: 4),
          _channelTile(MeshChannel.emergency,
              subtitle: tr(context, 'emergencyChannelSubtitle')),
          for (final c in _service.channels) _channelTile(c, showCode: true),
          if (_service.channels.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tr(context, 'noChannelsHint'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
        ],
      );
  }

  Widget _buildOnboarding(BuildContext context) {
    final formWidth =
        (MediaQuery.of(context).size.width - 48).clamp(320.0, 420.0).toDouble();
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'meshTitle'))),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: formWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cell_tower,
                      size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(tr(context, 'meshOnboardTitle'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, 'meshOnboardDesc'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'deviceNameLabel'),
                      hintText: tr(context, 'deviceNameHint'),
                    ),
                    onSubmitted: (_) => _saveName(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saveName,
                    icon: const Icon(Icons.check),
                    label: Text(tr(context, 'start')),
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
                  Row(
                    children: [
                      const Icon(Icons.sos, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr(context, 'sosActiveDesc'),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red.shade900),
                    onPressed: () => _service.cancelSos(),
                    icon: const Icon(Icons.check_circle),
                    label: Text(tr(context, 'imSafeCancelSos')),
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
            title: Text(tr(context, 'emergencyAskHelp')),
            subtitle: Text(tr(context, 'sosCardSubtitle')),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.offline_bolt, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(tr(context, 'meshOnboardSubtitle'),
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tr(context, 'meshInstructions')),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(Icons.wifi_tethering, size: 18),
                      label: Text('LAN/hotspot'),
                    ),
                    Chip(
                      avatar: Icon(Icons.bluetooth, size: 18),
                      label: Text('Bluetooth LE'),
                    ),
                    Chip(
                      avatar: Icon(Icons.wifi, size: 18),
                      label: Text('Wi‑Fi Direct'),
                    ),
                    Chip(
                      avatar: Icon(Icons.settings_input_antenna, size: 18),
                      label: Text('LoRa radio'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.settings_input_antenna),
            title: Text(tr(context, 'loraTitle')),
            subtitle: Text(tr(context, 'loraSubtitle')),
            value: MeshService.loraEnabled,
            onChanged: (v) async {
              await _service.setLoraEnabled(v);
              if (mounted) setState(() {});
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ValueListenableBuilder(
              valueListenable: _service.queuedCount,
              builder: (context, queued, _) => queued == 0
                  ? const SizedBox.shrink()
                  : Chip(
                      avatar: const Icon(Icons.schedule_send, size: 18),
                      label: Text('$queued ${tr(context, 'queuedNoReach')}'),
                    ),
            ),
            const Spacer(),
            Text(tr(context, 'shareMyPosition')),
            ValueListenableBuilder(
              valueListenable: _service.sharingPosition,
              builder: (context, sharing, _) => Switch(
                value: sharing,
                onChanged: (v) => _service.setSharePosition(v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _channelTile(MeshChannel channel,
      {String? subtitle, bool showCode = false}) {
    final last = _service.store.loadMessages(channel.id, limit: 1);
    final preview = last.isEmpty
        ? (subtitle ?? tr(context, 'noMessagesHint'))
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
        title: Text(isEmergency ? tr(context, 'emergencyChannelTitle') : channel.name),
        subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCode)
              IconButton(
                tooltip: tr(context, 'showChannelCodeTooltip'),
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
    // Repaint check marks when a delivery ACK arrives.
    _service.ackTick.addListener(_onAck);
    _sub = _service.events.listen((e) {
      if (e.channel.id != widget.channel.id) return;
      if (e.envelope.type != MeshType.chat && e.envelope.type != MeshType.sos) {
        return;
      }
      setState(() {
        _messages.add({
          ...e.payload,
          '_from': e.envelope.senderId,
          '_name': e.envelope.senderName,
          '_type': e.envelope.type.name,
          '_ts': e.envelope.timestampMs,
          '_msgId': e.envelope.msgId,
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

  void _onAck() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.ackTick.removeListener(_onAck);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isEmergency
                ? tr(context, 'emergencyChannelTitleAll')
                : widget.channel.name),
            // Live presence: whether any device is currently reachable. This
            // is the "is the other person online?" indicator.
            ValueListenableBuilder<int>(
              valueListenable: _service.peerCount,
              builder: (context, count, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle,
                      size: 9,
                      color: count > 0 ? Colors.lightGreenAccent : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    count > 0
                        ? '$count ${tr(context, 'online')}'
                        : tr(context, 'noneInRange'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isEmergency ? Colors.red.shade900 : null,
      ),
      body: Column(
        children: [
          if (isEmergency)
            Container(
              width: double.infinity,
              color: Colors.red.shade900.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(8),
              child: Text(
                tr(context, 'emergencyWarning'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _service.peerCount,
              builder: (context, count, _) => _messages.isEmpty
                  ? Center(
                      child: Text(
                        count > 0
                            ? tr(context, 'noMessagesHint')
                            : tr(context, 'noDevicesHint'),
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
                            constraints: BoxConstraints(
                              maxWidth:
                                  (MediaQuery.of(context).size.width * 0.86)
                                      .clamp(140.0, 560.0),
                            ),
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)),
                                Text(isSos
                                    ? '🆘 SOS ${m['note'] ?? ''} '
                                        '(${m['lat']?.toStringAsFixed(4)}, '
                                        '${m['lon']?.toStringAsFixed(4)})'
                                    : m['text'] as String? ?? ''),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _fmtTime(m['_ts'] as int?),
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                    // Delivery state for OUR messages: single
                                    // check = sent, double = a peer confirmed
                                    // receipt (ACK). Only chat carries ACKs.
                                    if (mine && !isSos) ...[
                                      const SizedBox(width: 4),
                                      Builder(builder: (_) {
                                        final id = m['_msgId'] as int?;
                                        final delivered = id != null &&
                                            _service.isDelivered(id);
                                        return Icon(
                                          delivered
                                              ? Icons.done_all
                                              : Icons.done,
                                          size: 13,
                                          color: delivered
                                              ? Colors.lightBlueAccent
                                              : Colors.grey,
                                        );
                                      }),
                                    ],
                                  ],
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
                            ? tr(context, 'messageHintEmergency')
                            : tr(context, 'messageHint'),
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
