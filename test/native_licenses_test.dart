import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/native_licenses.dart';

/// Candado legal: llama.cpp (MIT) y zstd (BSD) están COMPILADOS DENTRO de
/// libppllm. Ambas licencias exigen incluir el texto completo del aviso en
/// toda distribución del binario — nombrarlas no alcanza.
///
/// Flutter no las ve solas: su LicenseRegistry solo conoce paquetes Dart/pub,
/// y estas dos entran por FFI como código nativo. Sin este registro explícito
/// no aparecían en ningún lado de la app.
void main() {
  setUp(() {
    LicenseRegistry.reset();
    NativeLicenses.resetForTest();
  });

  test('registra llama.cpp y zstd, que Flutter no puede descubrir solo', () {
    NativeLicenses.register();
    final packages = NativeLicenses.entries.expand((e) => e.packages).toSet();
    expect(packages, containsAll(<String>['llama.cpp (ggml)', 'Zstandard']));
  });

  test('incluye el TEXTO completo, no solo el nombre de la licencia', () {
    NativeLicenses.register();
    for (final entry in NativeLicenses.entries) {
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(text.length, greaterThan(500),
          reason: '${entry.packages}: el texto está truncado; MIT y BSD '
              'exigen reproducir el aviso completo');
      expect(text, contains('Copyright'),
          reason: '${entry.packages}: falta el aviso de copyright');
    }
  });

  test('conserva el aviso de garantía, que ambas licencias obligan a incluir',
      () {
    NativeLicenses.register();
    for (final entry in NativeLicenses.entries) {
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(text.toUpperCase(), contains('WARRANT'),
          reason: '${entry.packages}: falta el descargo de garantía');
    }
  });

  test('llega a LicenseRegistry, que es lo que muestra la app', () async {
    NativeLicenses.register();
    final found = <String>{};
    await for (final entry in LicenseRegistry.licenses) {
      found.addAll(entry.packages);
    }
    expect(found, containsAll(<String>['llama.cpp (ggml)', 'Zstandard']),
        reason: 'si no está en LicenseRegistry, showLicensePage no lo muestra '
            'y la app se distribuye incumpliendo MIT y BSD');
  });

  test('registrar dos veces no duplica los avisos', () {
    NativeLicenses.register();
    NativeLicenses.register();
    expect(NativeLicenses.entries.length, 2);
  });
}
