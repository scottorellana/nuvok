import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled assets stay lightweight for low-RAM devices', () {
    final assetsDir = Directory('assets');
    expect(assetsDir.existsSync(), isTrue);

    final files = assetsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => !f.path.endsWith('.DS_Store'))
        .toList();
    final totalBytes = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
    final largest = files
      ..sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));

    expect(files, isNotEmpty);
    expect(totalBytes, lessThan(1024 * 1024),
        reason: 'assets bundled in-app must stay under 1 MB');
    expect(largest.first.lengthSync(), lessThan(256 * 1024),
        reason: 'no heavy raster/SVG payload should be bundled');
  });
}
