// Avisos de licencia del código NATIVO que Nuvok distribuye dentro de su
// binario.
//
// Por qué existe este archivo: llama.cpp (MIT) y zstd (BSD) se compilan
// estáticamente dentro de libppllm y viajan en cada copia de la app. Las dos
// licencias exigen reproducir su aviso completo en la distribución binaria —
// no basta con mencionarlas.
//
// Flutter no puede descubrirlas: su LicenseRegistry se alimenta del grafo de
// paquetes de pub, y estas dos entran por FFI como código nativo. Sin este
// registro explícito no aparecen en showLicensePage y la app se distribuye
// incumpliendo ambas licencias.
//
// Los textos están copiados literalmente de los LICENSE de cada proyecto. No
// editarlos: reproducirlos íntegros es justamente lo que la licencia obliga.
import 'package:flutter/foundation.dart';

const String _llamaCppLicense = '''
MIT License

Copyright (c) 2023-2026 The ggml authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

const String _zstdLicense = '''
BSD License

For Zstandard software

Copyright (c) Meta Platforms, Inc. and affiliates. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

 * Neither the name Facebook, nor Meta, nor the names of its contributors may
   be used to endorse or promote products derived from this software without
   specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.''';

class NativeLicenses {
  NativeLicenses._();

  static bool _registered = false;

  /// Los avisos que se añaden a la lista de licencias de la app.
  static final List<LicenseEntryWithLineBreaks> entries = [
    LicenseEntryWithLineBreaks(
        const ['llama.cpp (ggml)'], _llamaCppLicense),
    LicenseEntryWithLineBreaks(const ['Zstandard'], _zstdLicense),
  ];

  /// Añade los avisos nativos a [LicenseRegistry]. Llamar una vez al arrancar,
  /// antes de que se pueda abrir showLicensePage.
  ///
  /// Es idempotente: LicenseRegistry no permite quitar lo ya añadido, así que
  /// un segundo registro duplicaría los avisos en pantalla.
  static void register() {
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(() => Stream.fromIterable(entries));
  }

  /// Olvida que ya se registró. Solo para tests; el reset de LicenseRegistry
  /// corre del lado del test, que es donde Flutter permite tocarlo.
  @visibleForTesting
  static void resetForTest() => _registered = false;
}
