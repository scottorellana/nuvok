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
    this.bundled = false,
  }) {
    _validate();
  }

  final String kind;
  final String label;
  final String assetPath;
  final String targetRelativePath;
  final int bytes;
  final String sha256;

  /// True si este contenido viaja DENTRO del instalador. False = paquete que
  /// el usuario elige y descarga desde Depósito.
  ///
  /// Por defecto false a propósito: si alguien añade una entrada al manifiesto
  /// y olvida el campo, el resultado seguro es no empaquetarla (la app la
  /// ofrece como descarga) en vez de inflar el instalador en silencio.
  final bool bundled;

  factory BundledLibraryEntry.fromJson(Map<String, dynamic> json) {
    return BundledLibraryEntry(
      kind: json['kind'] as String? ?? '',
      label: json['label'] as String? ?? '',
      assetPath: json['asset'] as String? ?? '',
      targetRelativePath: json['target'] as String? ?? '',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
      bundled: json['bundled'] as bool? ?? false,
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

  /// Los assets mayores a esto no viajan en el APK de Android (el formato
  /// APK tiene un techo práctico de ~4GB y la compresión de assets de AGP
  /// revienta con arrays >2GB); el build.gradle los excluye del paquete.
  static const int androidAssetLimitBytes = 2 * 1024 * 1024 * 1024;

  /// Qué entradas del manifiesto sembrar en la biblioteca del usuario.
  ///
  /// Solo se puede sembrar lo que viaja dentro del instalador: el resto no
  /// existe como asset y el copiado fallaría. Lo no empaquetado llega por
  /// Depósito, que escribe directo en la biblioteca.
  ///
  /// El techo del APK de Android se sigue aplicando como red de seguridad:
  /// aunque hoy nada empaquetado se le acerca, un asset gigante que se colara
  /// haría fallar el build de Android antes que a nadie más.
  ///
  /// Pura, para poder verificar la decisión sin tocar Platform ni disco.
  static List<BundledLibraryEntry> entriesToSeed(
    List<BundledLibraryEntry> all, {
    required bool isIOS,
    bool isAndroid = false,
  }) {
    final bundled = all.where((e) => e.bundled);
    if (isAndroid) {
      return bundled.where((e) => e.bytes <= androidAssetLimitBytes).toList();
    }
    return bundled.toList();
  }

  static Future<BundledSeedResult> seed({
    NuvokLibrary? library,
    bool overwrite = false,
  }) async {
    final lib = library ?? NuvokLibrary.instance;
    await lib.ensure();
    final manifest = await BundledLibraryManifest.load();
    final entries = entriesToSeed(manifest.entries,
        isIOS: Platform.isIOS, isAndroid: Platform.isAndroid);
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
