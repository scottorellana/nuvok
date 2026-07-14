import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'nuvok_library.dart';

const _bundledAssetsChannel = MethodChannel('nuvok/bundled_assets');

class BundledLibraryManifest {
  BundledLibraryManifest({required this.version, required this.entries});

  final int version;
  final List<BundledLibraryEntry> entries;

  static const assetPath = 'assets/bundled_library/manifest.json';

  factory BundledLibraryManifest.fromJson(Map<String, dynamic> json) {
    final entriesJson = (json['entries'] as List? ?? const [])
        .cast<Map>()
        .map((e) => BundledLibraryEntry.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
    return BundledLibraryManifest(
      version: (json['version'] as num?)?.toInt() ?? 1,
      entries: entriesJson,
    );
  }

  static Future<BundledLibraryManifest> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return BundledLibraryManifest.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}

class BundledLibraryEntry {
  BundledLibraryEntry({
    required this.kind,
    required this.label,
    required this.assetPath,
    required this.targetRelativePath,
    required this.bytes,
    required this.sha256,
  }) {
    _validate();
  }

  final String kind;
  final String label;
  final String assetPath;
  final String targetRelativePath;
  final int bytes;
  final String sha256;

  factory BundledLibraryEntry.fromJson(Map<String, dynamic> json) {
    return BundledLibraryEntry(
      kind: json['kind'] as String? ?? '',
      label: json['label'] as String? ?? '',
      assetPath: json['asset'] as String? ?? '',
      targetRelativePath: json['target'] as String? ?? '',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
    );
  }

  void _validate() {
    if (!assetPath.startsWith('assets/bundled_library/')) {
      throw ArgumentError.value(assetPath, 'assetPath', 'fuera del bundle');
    }
    final parts = targetRelativePath.split('/');
    if (targetRelativePath.isEmpty ||
        targetRelativePath.startsWith('/') ||
        parts.contains('..')) {
      throw ArgumentError.value(
        targetRelativePath,
        'targetRelativePath',
        'ruta insegura',
      );
    }
    if (!const {'maps', 'zim', 'models', 'notes'}.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', 'categoría desconocida');
    }
    if (bytes <= 0) {
      throw ArgumentError.value(bytes, 'bytes', 'debe ser positivo');
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
      throw ArgumentError.value(sha256, 'sha256', 'checksum inválido');
    }
  }

  File resolveTarget(Directory root) =>
      File('${root.path}/$targetRelativePath');
}

class BundledSeedResult {
  const BundledSeedResult({
    required this.copied,
    required this.skipped,
    required this.errors,
  });

  final List<String> copied;
  final List<String> skipped;
  final Map<String, String> errors;

  bool get ok => errors.isEmpty;
}

class BundledLibrarySeeder {
  const BundledLibrarySeeder._();

  /// Which bundled entries a given platform should seed.
  ///
  /// iOS seeds ONLY the AI model: every bundled asset already ships inside the
  /// .app, so copying it into the library doubles storage. On a phone the maps
  /// (~270MB) + medical ZIM (~650MB) doubling is not worth it yet, but the AI
  /// model is what powers the specialists and must be installed for them to
  /// run offline. Android/macOS (single-install desktops/tablets) seed
  /// everything. Pure so the per-platform choice is unit-testable without
  /// touching Platform or doing IO.
  static List<BundledLibraryEntry> entriesToSeed(
    List<BundledLibraryEntry> all, {
    required bool isIOS,
  }) =>
      isIOS ? all.where((e) => e.kind == 'models').toList() : all;

  static Future<BundledSeedResult> seed({
    NuvokLibrary? library,
    bool overwrite = false,
  }) async {
    final lib = library ?? NuvokLibrary.instance;
    await lib.ensure();
    final manifest = await BundledLibraryManifest.load();
    final entries = entriesToSeed(manifest.entries, isIOS: Platform.isIOS);
    final copied = <String>[];
    final skipped = <String>[];
    final errors = <String, String>{};

    for (final entry in entries) {
      final target = entry.resolveTarget(lib.root);
      try {
        if (!overwrite && _looksInstalled(target, entry)) {
          skipped.add(entry.targetRelativePath);
          continue;
        }
        await target.parent.create(recursive: true);
        if (Platform.isAndroid || Platform.isMacOS || Platform.isIOS) {
          // Native streaming copy: reads the asset in 1MB chunks on the OS
          // side so a ~500MB model never lands whole in RAM (iOS jetsam).
          await _copyNativeAsset(entry, target);
        } else {
          await _copyFlutterAsset(entry, target);
        }
        copied.add(entry.targetRelativePath);
      } catch (e) {
        errors[entry.targetRelativePath] = e.toString();
      }
    }

    return BundledSeedResult(copied: copied, skipped: skipped, errors: errors);
  }

  static bool _looksInstalled(File target, BundledLibraryEntry entry) {
    try {
      return target.existsSync() && target.lengthSync() == entry.bytes;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _copyNativeAsset(
    BundledLibraryEntry entry,
    File target,
  ) async {
    await _bundledAssetsChannel.invokeMethod<void>('copyAsset', {
      'asset': entry.assetPath,
      'dest': target.path,
      'bytes': entry.bytes,
      'sha256': entry.sha256,
    });
  }

  static Future<void> _copyFlutterAsset(
    BundledLibraryEntry entry,
    File target,
  ) async {
    final data = await rootBundle.load(entry.assetPath);
    if (data.lengthInBytes != entry.bytes) {
      throw StateError(
        'Tamaño inesperado para ${entry.assetPath}: '
        '${data.lengthInBytes} != ${entry.bytes}',
      );
    }
    final digest = sha256.convert(data.buffer.asUint8List()).toString();
    if (digest != entry.sha256) {
      throw StateError('Checksum inválido para ${entry.assetPath}');
    }
    // Atomic copy: write tmp + rename over the target. We do NOT delete
    // the target first — rename(2) is atomic on POSIX/NTFS and replacing
    // an existing destination is fine. This prevents data loss if the
    // process is killed between delete and rename.
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(data.buffer.asUint8List(), flush: true);
    try {
      await tmp.rename(target.path);
    } catch (_) {
      // Cleanup the tmp if rename failed (e.g. cross-device, permission).
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }
}
