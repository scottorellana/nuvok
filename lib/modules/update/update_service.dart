// Opportunistic update checker: when the device happens to have internet
// (this app never requires it), it fetches a small public manifest, compares
// versions, and — if there's something newer — downloads and offers to
// install it. Every step degrades silently when offline: a failed check is
// not an error the user needs to see, it's just "try again next time you
// have signal".
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/prepper_library.dart';
import 'update_manifest.dart';

enum UpdateState {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  downloaded,
  error
}

class UpdateService extends ChangeNotifier {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// LAN-first by design: this build keeps everything private, so updates are
  /// served by the Prepper Pad "installer-server" running on a computer on the
  /// same WiFi (it already exposes /version.json + the binaries). There is no
  /// public host. The address is derived from the local server the user set
  /// for maps, or set explicitly here — see [resolveManifestUrl].
  static const String defaultManifestUrl = '';

  String _manifestUrl = defaultManifestUrl;
  String get manifestUrl => _manifestUrl;

  /// Whether we have somewhere to check at all (a local server is configured).
  bool get hasManifestSource => _manifestUrl.isNotEmpty;

  UpdateState state = UpdateState.idle;
  UpdateManifest? latest;
  String? currentVersion;
  String? error;
  double downloadProgress = 0; // 0..1
  File? downloadedFile;

  bool get updateAvailable =>
      state == UpdateState.available || state == UpdateState.downloaded;

  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    currentVersion = info.version;
    _manifestUrl = _resolveManifestUrl();
  }

  /// Resolves where to check for updates: an explicit override wins, otherwise
  /// we reuse the local map/content server the user already configured (the
  /// installer-server serves /version.json too). Keeps a single "your computer
  /// on the WiFi" address for both maps and updates.
  String _resolveManifestUrl() {
    final settings = PrepperLibrary.instance.settings;
    final explicit = settings['updateManifestUrl'] as String?;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final localServer = settings['localMapServer'] as String?;
    if (localServer != null && localServer.isNotEmpty) {
      return '${localServer.replaceAll(RegExp(r'/+$'), '')}/version.json';
    }
    return defaultManifestUrl;
  }

  /// Point updates at a local server base URL (e.g. http://192.168.1.5:8848).
  /// Shared with the maps installer so the user configures it once.
  Future<void> setLocalServer(String baseUrl) async {
    final clean = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    await PrepperLibrary.instance.saveSetting('localMapServer', clean);
    _manifestUrl = clean.isEmpty ? defaultManifestUrl : '$clean/version.json';
    notifyListeners();
  }

  Future<void> setManifestUrl(String url) async {
    _manifestUrl = url.trim();
    await PrepperLibrary.instance
        .saveSetting('updateManifestUrl', _manifestUrl);
    notifyListeners();
  }

  /// Checks for an update. Safe to call anytime (app start, manual button,
  /// pull-to-refresh) — never throws, never blocks, and does nothing harmful
  /// if there's no connection.
  Future<void> check({Duration timeout = const Duration(seconds: 6)}) async {
    // Re-resolve in case the user just set the local server.
    if (_manifestUrl.isEmpty) _manifestUrl = _resolveManifestUrl();
    if (_manifestUrl.isEmpty) {
      // No update source configured yet — not an error the user did wrong.
      state = UpdateState.error;
      error = 'Configura el servidor local para buscar actualizaciones.';
      notifyListeners();
      return;
    }
    state = UpdateState.checking;
    error = null;
    notifyListeners();
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      currentVersion ??= (await PackageInfo.fromPlatform()).version;
      final req = await client.getUrl(Uri.parse(_manifestUrl)).timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      final manifest =
          UpdateManifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
      latest = manifest;
      final asset = _assetForThisPlatform(manifest);
      if (asset != null &&
          compareSemver(manifest.version, currentVersion!) > 0) {
        state = UpdateState.available;
      } else {
        state = UpdateState.upToDate;
      }
    } catch (e) {
      // No internet, DNS failure, manifest not hosted yet, etc. — this is
      // the expected common case for an offline-first app, not a crash.
      state = UpdateState.error;
      error = e.toString();
    } finally {
      // close() must run on every exit path. Without this, a mid-stream
      // network drop leaks the HttpClient and its sockets — repeated failed
      // check() calls would accumulate until OOM.
      client.close(force: true);
    }
    notifyListeners();
  }

  UpdatePlatformAsset? _assetForThisPlatform(UpdateManifest m) {
    final key = Platform.isAndroid
        ? 'android'
        : Platform.isMacOS
            ? 'macos'
            : Platform.isWindows
                ? 'windows'
                : Platform.isLinux
                    ? 'linux'
                    : null;
    if (key == null) return null;
    return m.platforms[key];
  }

  Uri _resolveAssetUri(String rawUrl) {
    final uri = Uri.parse(rawUrl.trim());
    final base = Uri.parse(_manifestUrl);
    final resolved = uri.hasScheme ? uri : base.resolveUri(uri);
    if (resolved.scheme != 'http' && resolved.scheme != 'https') {
      throw const FormatException(
          'Solo se permiten actualizaciones http/https');
    }
    if (resolved.userInfo.isNotEmpty) {
      throw const FormatException(
          'URL de actualización con credenciales no permitida');
    }
    // LAN/offline updates are same-origin: the manifest and APK/DMG must come
    // from the same local installer. This avoids a malicious/stale manifest
    // redirecting downloads to arbitrary hosts while still supporting relative
    // /download/... URLs from installer-server.
    if (resolved.scheme != base.scheme ||
        resolved.host != base.host ||
        resolved.port != base.port) {
      throw const FormatException(
          'El instalador debe estar en el mismo servidor que el manifiesto');
    }
    return resolved;
  }

  String _downloadFileName(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty || segments.last.isEmpty) {
      return 'prepper-pad-update.bin';
    }
    final name = segments.last;
    final safe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$');
    if (name == '.' || name == '..' || !safe.hasMatch(name)) {
      throw const FormatException('Nombre de instalador inseguro');
    }
    return name;
  }

  /// Downloads the update for this platform to the library's updates folder,
  /// verifying the checksum when the manifest provides one — a corrupt or
  /// tampered download must never be handed to the OS installer.
  Future<void> download() async {
    final m = latest;
    final asset = m == null ? null : _assetForThisPlatform(m);
    if (asset == null) return;
    state = UpdateState.downloading;
    downloadProgress = 0;
    error = null;
    notifyListeners();
    final client = HttpClient();
    IOSink? sink;
    try {
      final dir = await _updatesDir();
      final assetUri = _resolveAssetUri(asset.url);
      final fileName = _downloadFileName(assetUri);
      final dest = File('${dir.path}/$fileName');
      final part = File('${dest.path}.part');

      final req = await client.getUrl(assetUri);
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}', uri: assetUri);
      }
      final total = asset.sizeBytes;
      var received = 0;
      sink = part.openWrite();
      await for (final chunk in res) {
        received += chunk.length;
        if (received > total) {
          throw Exception('Descarga excede el tamaño esperado');
        }
        sink.add(chunk);
        downloadProgress = received / total;
        notifyListeners();
      }
      await sink.close();
      sink = null;

      if (received != total) {
        await part.delete();
        throw Exception('Descarga incompleta ($received != $total bytes)');
      }

      // Hash the file as a stream. Release APK/DMG files can be >1 GB; reading
      // them with readAsBytes() would spike RAM and can kill the app on phones.
      final got = await sha256.bind(part.openRead()).first;
      if (got.toString() != asset.sha256.toLowerCase()) {
        await part.delete();
        throw Exception(
            'Verificación de integridad fallida (sha256 no coincide)');
      }
      if (await dest.exists()) await dest.delete();
      await part.rename(dest.path);
      downloadedFile = dest;
      state = UpdateState.downloaded;
    } catch (e) {
      state = UpdateState.error;
      error = e.toString();
    } finally {
      // Close the sink first (if it's still open after an exception), then
      // the HTTP client. Without this, a network drop mid-stream leaks
      // both the file writer and the HttpClient.
      try {
        await sink?.close();
      } catch (_) {}
      client.close(force: true);
    }
    notifyListeners();
  }

  Future<Directory> _updatesDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/updates');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Hands the downloaded file to the OS. Android opens the system package
  /// installer via a proper FileProvider-backed intent (user must tap
  /// Install — a normal app cannot invoke `am`/shell and Android does not
  /// allow silent self-update outside app stores, by design). macOS mounts
  /// the .dmg in Finder for the familiar drag-to-Applications flow. Windows
  /// and Linux launch the downloaded installer with the OS file handler.
  /// None of these replace the running binary directly, which is the safe,
  /// standard pattern outside app stores.
  Future<void> install() async {
    final file = downloadedFile;
    if (file == null) return;
    try {
      if (Platform.isAndroid) {
        await OpenFilex.open(file.path,
            type: 'application/vnd.android.package-archive');
      } else if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [file.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.path]);
      }
    } catch (_) {
      // Fall through — the UI still shows the file path so the user can open
      // it manually from their file manager.
    }
  }
}
