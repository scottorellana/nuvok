// FFI bindings for cluster decompression: zstd (bundled dylib) and
// liblzma (system library on macOS/Linux, bundled on Windows).
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------------------
// zstd
// ---------------------------------------------------------------------------

final class ZstdInBuffer extends Struct {
  external Pointer<Uint8> src;
  @Size()
  external int size;
  @Size()
  external int pos;
}

final class ZstdOutBuffer extends Struct {
  external Pointer<Uint8> dst;
  @Size()
  external int size;
  @Size()
  external int pos;
}

class _Zstd {
  _Zstd(DynamicLibrary lib)
      : createDCtx = lib.lookupFunction<Pointer<Void> Function(),
            Pointer<Void> Function()>('ZSTD_createDCtx'),
        freeDCtx = lib.lookupFunction<Size Function(Pointer<Void>),
            int Function(Pointer<Void>)>('ZSTD_freeDCtx'),
        decompressStream = lib.lookupFunction<
            Size Function(
                Pointer<Void>, Pointer<ZstdOutBuffer>, Pointer<ZstdInBuffer>),
            int Function(Pointer<Void>, Pointer<ZstdOutBuffer>,
                Pointer<ZstdInBuffer>)>('ZSTD_decompressStream'),
        isError =
            lib.lookupFunction<UnsignedInt Function(Size), int Function(int)>(
                'ZSTD_isError');

  final Pointer<Void> Function() createDCtx;
  final int Function(Pointer<Void>) freeDCtx;
  final int Function(
          Pointer<Void>, Pointer<ZstdOutBuffer>, Pointer<ZstdInBuffer>)
      decompressStream;
  final int Function(int) isError;
}

DynamicLibrary _openZstd() {
  if (Platform.isIOS) {
    // Shipped as a dynamic framework (Nuvok_native pod). Dynamic — not
    // static — because FFI resolves symbols at runtime and a static lib
    // would be dead-stripped by the linker.
    return DynamicLibrary.open('zstd.framework/zstd');
  }
  if (Platform.isMacOS) {
    // Bundled in the .app's Frameworks directory; falls back to dev paths.
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir/../Frameworks/libzstd.1.dylib',
      // Relative to the working directory — how CI and `flutter test` find
      // the freshly built dylib (cwd is the repo root during tests).
      'native/out/macos/libzstd.1.dylib',
      '${Directory.current.path}/native/out/macos/libzstd.1.dylib',
      '${Platform.environment['HOME']}/Nuvok-pad/native/out/macos/libzstd.1.dylib',
      '${Platform.environment['HOME']}/development/zstd/lib/libzstd.dylib',
      'libzstd.1.dylib',
    ];
    for (final name in candidates) {
      try {
        return DynamicLibrary.open(name);
      } catch (_) {}
    }
    throw UnsupportedError('No se encontró libzstd (macOS)');
  }
  if (Platform.isWindows) return DynamicLibrary.open('libzstd.dll');
  // Linux / Android
  for (final name in ['libzstd.so.1', 'libzstd.so']) {
    try {
      return DynamicLibrary.open(name);
    } catch (_) {}
  }
  throw UnsupportedError('No se encontró libzstd en este sistema');
}

final _Zstd _zstd = _Zstd(_openZstd());

/// Decompresses a full zstd frame of unknown decompressed size.
Uint8List zstdDecompress(Uint8List compressed, {int sizeHint = 1 << 20}) {
  final dctx = _zstd.createDCtx();
  final srcPtr = malloc<Uint8>(compressed.length);
  final inBuf = malloc<ZstdInBuffer>();
  final outBuf = malloc<ZstdOutBuffer>();
  const chunk = 1 << 18; // 256 KiB output chunks
  final dstPtr = malloc<Uint8>(chunk);
  try {
    srcPtr.asTypedList(compressed.length).setAll(0, compressed);
    inBuf.ref
      ..src = srcPtr
      ..size = compressed.length
      ..pos = 0;
    final builder = BytesBuilder(copy: true);
    while (true) {
      outBuf.ref
        ..dst = dstPtr
        ..size = chunk
        ..pos = 0;
      final ret = _zstd.decompressStream(dctx, outBuf, inBuf);
      if (_zstd.isError(ret) != 0) {
        throw const FormatException('Cluster zstd corrupto');
      }
      if (outBuf.ref.pos > 0) {
        builder.add(dstPtr.asTypedList(outBuf.ref.pos));
      }
      // ret == 0 → frame complete. Otherwise continue while input remains
      // or the decoder still has buffered output to flush.
      if (ret == 0) break;
      if (inBuf.ref.pos >= inBuf.ref.size && outBuf.ref.pos < chunk) {
        break; // no more input and decoder made no full chunk: done/truncated
      }
    }
    return builder.takeBytes();
  } finally {
    _zstd.freeDCtx(dctx);
    malloc.free(srcPtr);
    malloc.free(dstPtr);
    malloc.free(inBuf);
    malloc.free(outBuf);
  }
}

// ---------------------------------------------------------------------------
// liblzma (xz) — used by older ZIM files
// ---------------------------------------------------------------------------

final class LzmaStream extends Struct {
  external Pointer<Uint8> nextIn;
  @Size()
  external int availIn;
  @Uint64()
  external int totalIn;
  external Pointer<Uint8> nextOut;
  @Size()
  external int availOut;
  @Uint64()
  external int totalOut;
  external Pointer<Void> allocator;
  external Pointer<Void> internal;
  external Pointer<Void> reservedPtr1;
  external Pointer<Void> reservedPtr2;
  external Pointer<Void> reservedPtr3;
  external Pointer<Void> reservedPtr4;
  @Uint64()
  external int reservedInt1;
  @Uint64()
  external int reservedInt2;
  @Size()
  external int reservedInt3;
  @Size()
  external int reservedInt4;
  @Uint32()
  external int reservedEnum1;
  @Uint32()
  external int reservedEnum2;
}

class _Lzma {
  _Lzma(DynamicLibrary lib)
      : autoDecoder = lib.lookupFunction<
            Int32 Function(Pointer<LzmaStream>, Uint64, Uint32),
            int Function(Pointer<LzmaStream>, int, int)>('lzma_auto_decoder'),
        code = lib.lookupFunction<Int32 Function(Pointer<LzmaStream>, Int32),
            int Function(Pointer<LzmaStream>, int)>('lzma_code'),
        end = lib.lookupFunction<Void Function(Pointer<LzmaStream>),
            void Function(Pointer<LzmaStream>)>('lzma_end');

  final int Function(Pointer<LzmaStream>, int, int) autoDecoder;
  final int Function(Pointer<LzmaStream>, int) code;
  final void Function(Pointer<LzmaStream>) end;
}

DynamicLibrary _openLzma() {
  if (Platform.isIOS) {
    // Apple ships liblzma in the OS; the Nuvok_native pod links it so the
    // symbols are already in the process image.
    try {
      return DynamicLibrary.process();
    } catch (_) {
      return DynamicLibrary.open('/usr/lib/liblzma.5.dylib');
    }
  }
  if (Platform.isMacOS) return DynamicLibrary.open('/usr/lib/liblzma.5.dylib');
  if (Platform.isWindows) return DynamicLibrary.open('liblzma.dll');
  for (final name in ['liblzma.so.5', 'liblzma.so']) {
    try {
      return DynamicLibrary.open(name);
    } catch (_) {}
  }
  throw UnsupportedError('No se encontró liblzma en este sistema');
}

_Lzma? _lzmaCache;
_Lzma get _lzma => _lzmaCache ??= _Lzma(_openLzma());

const _lzmaRun = 0;
const _lzmaFinish = 3;
const _lzmaOk = 0;
const _lzmaStreamEnd = 1;

/// Decompresses an xz/lzma stream of unknown decompressed size.
Uint8List lzmaDecompress(Uint8List compressed) {
  final strm = calloc<LzmaStream>();
  final srcPtr = malloc<Uint8>(compressed.length);
  const chunk = 1 << 18;
  final dstPtr = malloc<Uint8>(chunk);
  try {
    final initRet = _lzma.autoDecoder(strm, 0xFFFFFFFFFFFFFFFF, 0);
    if (initRet != _lzmaOk) {
      throw const FormatException('No se pudo inicializar liblzma');
    }
    srcPtr.asTypedList(compressed.length).setAll(0, compressed);
    strm.ref
      ..nextIn = srcPtr
      ..availIn = compressed.length;
    final builder = BytesBuilder(copy: true);
    while (true) {
      strm.ref
        ..nextOut = dstPtr
        ..availOut = chunk;
      final action = strm.ref.availIn == 0 ? _lzmaFinish : _lzmaRun;
      final ret = _lzma.code(strm, action);
      final produced = chunk - strm.ref.availOut;
      if (produced > 0) builder.add(dstPtr.asTypedList(produced));
      if (ret == _lzmaStreamEnd) break;
      if (ret != _lzmaOk) {
        throw const FormatException('Cluster lzma corrupto');
      }
      if (strm.ref.availIn == 0 && produced == 0) break;
    }
    return builder.takeBytes();
  } finally {
    _lzma.end(strm);
    malloc.free(srcPtr);
    malloc.free(dstPtr);
    calloc.free(strm);
  }
}
