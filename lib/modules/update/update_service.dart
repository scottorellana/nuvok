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

  /// Public manifest URL. No auth, no secrets — this is what makes it safe
  /// to ship inside the app, unlike a token for the private source repo.
  /// Overridable so a build (or the user, via Configuración avanzada) can
  /// point at a different host without a code change.
  static const String defaultManifestUrl =
      'https://prepperpad.app/updates/version.json';

  String _manifestUrl = defaultManifestUrl;
  String get manifestUrl => _manifestUrl;

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
    final saved =
        PrepperLibrary.instance.settings['updateManifestUrl'] as String?;
    if (saved != null && saved.isNotEmpty) _manifestUrl = saved;
  }

  Future<void> setManifestUrl(String url) async {
    _manifestUrl = url.trim().isEmpty ? defaultManifestUrl : url.trim();
    await PrepperLibrary.instance
        .saveSetting('updateManifestUrl', _manifestUrl);
    notifyListeners();
  }

  /// Checks for an update. Safe to call anytime (app start, manual button,
  /// pull-to-refresh) — never throws, never blocks, and does nothing harmful
  /// if there's no connection.
  Future<void> check({Duration timeout = const Duration(seconds: 6)}) async {
    state = UpdateState.checking;
    error = null;
    notifyListeners();
    try {
      currentVersion ??= (await PackageInfo.fromPlatform()).version;
      final client = HttpClient()..connectionTimeout = timeout;
      final req = await client.getUrl(Uri.parse(_manifestUrl)).timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      client.close();
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
    try {
      final dir = await _updatesDir();
      final fileName = asset.url.split('/').last;
      final dest = File('${dir.path}/$fileName');
      final part = File('${dest.path}.part');

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(asset.url));
      final res = await req.close();
      final total =
          res.contentLength > 0 ? res.contentLength : asset.sizeBytes ?? 0;
      var received = 0;
      final sink = part.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          downloadProgress = received / total;
          notifyListeners();
        }
      }
      await sink.close();
      client.close();

      if (asset.sha256 != null) {
        // Hash the file we just wrote (these are tens of MB, fine to read
        // back in one pass) — a corrupt or tampered download must never
        // reach the OS installer.
        final got = sha256.convert(await part.readAsBytes()).toString();
        if (got.toLowerCase() != asset.sha256!.toLowerCase()) {
          await part.delete();
          throw Exception(
              'Verificación de integridad fallida (sha256 no coincide)');
        }
      }
      if (await dest.exists()) await dest.delete();
      await part.rename(dest.path);
      downloadedFile = dest;
      state = UpdateState.downloaded;
    } catch (e) {
      state = UpdateState.error;
      error = e.toString();
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
