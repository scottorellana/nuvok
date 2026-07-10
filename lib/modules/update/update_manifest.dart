// The update manifest is a tiny public JSON file (no auth, no secrets) that
// tells every installed copy of Nuvok what the latest version is and
// where to fetch it — independent of the private source repo. A private repo
// cannot serve release binaries to arbitrary devices without embedding a
// token in the shipped app, which would leak repo access to anyone who
// extracts it — so the manifest + binaries must live somewhere public.
//
// Shape:
// {
//   "version": "0.2.1",
//   "notes": "Qué cambió, en una o dos líneas.",
//   "platforms": {
//     "macos":   {"url": "https://.../Nuvok-0.2.1.dmg", "sha256": "...", "sizeBytes": 33500000},
//     "android": {"url": "https://.../Nuvok-pad-0.2.1.apk", "sha256": "...", "sizeBytes": 66000000}
//   }
// }
class UpdatePlatformAsset {
  UpdatePlatformAsset({
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  final String url;
  final String sha256; // hex digest, verified after download
  final int sizeBytes; // expected exact size; prevents unbounded disk writes

  factory UpdatePlatformAsset.fromJson(Map<String, dynamic> j) {
    final url = j['url'] as String?;
    final sha256 = j['sha256'] as String?;
    final sizeBytes = ((j['sizeBytes'] ?? j['size']) as num?)?.toInt();
    if (url == null || url.trim().isEmpty) {
      throw const FormatException('update asset url requerido');
    }
    if (sha256 == null || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('update asset sha256 inválido');
    }
    if (sizeBytes == null || sizeBytes <= 0) {
      throw const FormatException('update asset sizeBytes inválido');
    }
    return UpdatePlatformAsset(
      url: url,
      sha256: sha256.toLowerCase(),
      sizeBytes: sizeBytes,
    );
  }
}

class UpdateManifest {
  UpdateManifest({
    required this.version,
    required this.notes,
    required this.platforms,
  });

  final String version;
  final String notes;
  final Map<String, UpdatePlatformAsset>
      platforms; // key: macos, android, windows, linux

  factory UpdateManifest.fromJson(Map<String, dynamic> j) => UpdateManifest(
        version: j['version'] as String,
        notes: j['notes'] as String? ?? '',
        platforms: {
          for (final entry
              in (j['platforms'] as Map<String, dynamic>? ?? {}).entries)
            entry.key: UpdatePlatformAsset.fromJson(
                (entry.value as Map).cast<String, dynamic>()),
        },
      );
}

/// Simple X.Y.Z comparison — good enough for this app's own version scheme.
/// Returns >0 if [a] is newer than [b], 0 if equal, <0 if older.
int compareSemver(String a, String b) {
  List<int> parts(String v) => v
      .split('+')
      .first // drop a build-number suffix like "0.2.1+3" if present
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}
