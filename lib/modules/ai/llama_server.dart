// Manages the embedded llama.cpp server: an internal child process bound to
// 127.0.0.1 on an ephemeral port. Invisible implementation detail — the same
// approach LM Studio and Ollama use under the hood.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum LlamaStatus { stopped, starting, running, error }

class LlamaServer extends ChangeNotifier {
  LlamaServer._();
  static final LlamaServer instance = LlamaServer._();

  Process? _process;
  int? _port;
  String? _modelPath;
  final List<String> _recentOutput = [];
  LlamaStatus status = LlamaStatus.stopped;
  String? lastError;

  String? get modelPath => _modelPath;
  Uri get baseUri => Uri.parse('http://127.0.0.1:$_port');

  /// Locates the llama-server binary: bundled with the app, or the local
  /// development build as fallback.
  static String? findBinary() {
    final exe = File(Platform.resolvedExecutable);
    final candidates = <String>[];
    if (Platform.isMacOS) {
      // .app/Contents/MacOS/../Resources/bin/llama-server
      final contents = exe.parent.parent.path;
      candidates.add('$contents/Resources/bin/llama-server');
    } else if (Platform.isWindows) {
      candidates.add('${exe.parent.path}\\bin\\llama-server.exe');
    } else {
      candidates.add('${exe.parent.path}/bin/llama-server');
    }
    final home = Platform.environment['HOME'] ?? '';
    candidates.add('$home/Nuvok-pad/native/out/macos/llama-server');
    candidates.add('$home/development/llama.cpp/build/bin/llama-server');
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Rough free-memory estimate used to warn before loading a big model.
  static Future<int?> freeRamBytes() async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('vm_stat', []);
        final out = result.stdout as String;
        final pageSize =
            RegExp(r'page size of (\d+)').firstMatch(out)?.group(1) ?? '16384';
        int pages(String name) =>
            int.tryParse(
                RegExp('$name:\\s+(\\d+)').firstMatch(out)?.group(1) ?? '0') ??
            0;
        final free = pages('Pages free') +
            pages('Pages inactive') +
            pages('Pages purgeable');
        return free * int.parse(pageSize);
      }
      if (Platform.isLinux) {
        final meminfo = await File('/proc/meminfo').readAsString();
        final kb = int.tryParse(
            RegExp(r'MemAvailable:\s+(\d+) kB').firstMatch(meminfo)?.group(1) ??
                '');
        return kb == null ? null : kb * 1024;
      }
    } catch (_) {}
    return null;
  }

  Future<void> start(String modelPath) async {
    await stop();
    _recentOutput.clear();
    final binary = findBinary();
    if (binary == null) {
      status = LlamaStatus.error;
      lastError = 'No se encontró el motor de IA (llama-server) en la app.';
      notifyListeners();
      return;
    }
    status = LlamaStatus.starting;
    _modelPath = modelPath;
    lastError = null;
    notifyListeners();
    try {
      // Reserve an ephemeral port, then hand it to llama-server.
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _port = probe.port;
      await probe.close();

      _process = await Process.start(binary, [
        '-m',
        modelPath,
        '--host',
        '127.0.0.1',
        '--port',
        '$_port',
        '-c',
        '4096',
        '-ngl',
        '99',
        '--jinja',
      ]);
      _process!.exitCode.then((code) {
        if (status == LlamaStatus.running || status == LlamaStatus.starting) {
          status = LlamaStatus.error;
          final tail = _recentOutput.isEmpty ? '' : '\n${_recentOutput.join('\n')}';
          lastError = 'El motor de IA se cerró inesperadamente (código $code)$tail';
          _process = null;
          notifyListeners();
        }
      });
      // Drain output to avoid blocking the child.
      void remember(String chunk) {
        for (final line in chunk.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          _recentOutput.add(trimmed);
          if (_recentOutput.length > 8) _recentOutput.removeAt(0);
        }
      }

      _process!.stdout.transform(utf8.decoder).listen(remember);
      _process!.stderr.transform(utf8.decoder).listen(remember);

      // Wait for /health to come up (model load can take a while).
      final client = HttpClient();
      try {
        final deadline = DateTime.now().add(const Duration(minutes: 5));
        while (DateTime.now().isBefore(deadline)) {
          if (_process == null) return; // crashed during load
          try {
            final req = await client
                .getUrl(baseUri.replace(path: '/health'))
                .timeout(const Duration(seconds: 2));
            final res = await req.close().timeout(const Duration(seconds: 2));
            await res.drain<void>();
            if (res.statusCode == 200) {
              status = LlamaStatus.running;
              notifyListeners();
              return;
            }
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
        throw TimeoutException('El modelo tardó demasiado en cargar');
      } finally {
        client.close();
      }
    } catch (e) {
      status = LlamaStatus.error;
      lastError = e.toString();
      await stop(keepError: true);
      notifyListeners();
    }
  }

  Future<void> stop({bool keepError = false}) async {
    final p = _process;
    _process = null;
    if (p != null) {
      p.kill();
      await p.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
        p.kill(ProcessSignal.sigkill);
        return -1;
      });
    }
    if (!keepError) {
      status = LlamaStatus.stopped;
      lastError = null;
      _modelPath = null;
      notifyListeners();
    }
  }

  /// Streams assistant tokens for the given conversation.
  Stream<String> chat(List<Map<String, String>> messages) async* {
    if (status != LlamaStatus.running) {
      throw StateError('El motor de IA no está activo');
    }
    final client = HttpClient();
    try {
      final req =
          await client.postUrl(baseUri.replace(path: '/v1/chat/completions'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'messages': messages,
        'stream': true,
        'temperature': 0.7,
      }));
      final res = await req.close();
      if (res.statusCode != 200) {
        final body = await res.transform(utf8.decoder).join();
        throw HttpException('Error del motor (${res.statusCode}): $body');
      }
      var buffer = '';
      await for (final chunk in res.transform(utf8.decoder)) {
        buffer += chunk;
        while (buffer.contains('\n')) {
          final line = buffer.substring(0, buffer.indexOf('\n')).trim();
          buffer = buffer.substring(buffer.indexOf('\n') + 1);
          if (!line.startsWith('data: ')) continue;
          final payload = line.substring(6);
          if (payload == '[DONE]') return;
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            final delta = ((json['choices'] as List).first
                as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null) yield content;
          } catch (_) {
            // Ignore malformed keep-alive lines.
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
