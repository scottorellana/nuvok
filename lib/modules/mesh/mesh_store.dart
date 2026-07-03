// Persistence for the mesh: message history as JSONL per channel (append-only,
// crash-safe, human-inspectable) and the store-and-forward outbox. Lives in
// the portable library (~/PrepperPad/mesh) so history travels with it.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class MeshStore {
  MeshStore(this.dirPath) {
    Directory(dirPath).createSync(recursive: true);
  }

  final String dirPath;

  File _messagesFile(String channelId) => File('$dirPath/$channelId.jsonl');
  File get _outboxFile => File('$dirPath/outbox.json');
  File get _channelsFile => File('$dirPath/channels.json');

  void saveChannels(List<Map<String, dynamic>> channels) {
    try {
      _channelsFile.writeAsStringSync(jsonEncode(channels));
    } catch (_) {}
  }

  List<Map<String, dynamic>> loadChannels() {
    try {
      if (!_channelsFile.existsSync()) return [];
      final list = jsonDecode(_channelsFile.readAsStringSync()) as List;
      return [for (final e in list) (e as Map).cast<String, dynamic>()];
    } catch (_) {
      return [];
    }
  }

  void appendMessage(String channelId, Map<String, dynamic> record) {
    try {
      _messagesFile(channelId)
          .writeAsStringSync('${jsonEncode(record)}\n', mode: FileMode.append);
    } catch (_) {
      // Best-effort persistence; the live UI still has the message.
    }
  }

  List<Map<String, dynamic>> loadMessages(String channelId, {int limit = 500}) {
    try {
      final f = _messagesFile(channelId);
      if (!f.existsSync()) return [];
      final lines = f.readAsLinesSync();
      final start = lines.length > limit ? lines.length - limit : 0;
      return [
        for (final line in lines.sublist(start))
          if (line.trim().isNotEmpty)
            (jsonDecode(line) as Map).cast<String, dynamic>(),
      ];
    } catch (_) {
      return [];
    }
  }

  void saveOutbox(List<Uint8List> datagrams) {
    try {
      _outboxFile.writeAsStringSync(
          jsonEncode([for (final d in datagrams) base64.encode(d)]));
    } catch (_) {}
  }

  List<Uint8List> loadOutbox() {
    try {
      if (!_outboxFile.existsSync()) return [];
      final list = jsonDecode(_outboxFile.readAsStringSync()) as List;
      return [
        for (final s in list) Uint8List.fromList(base64.decode(s as String)),
      ];
    } catch (_) {
      return [];
    }
  }
}
