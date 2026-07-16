import CryptoKit
import Flutter
import Foundation

/// iOS side of the `nuvok/bundled_assets` channel — mirror of the macOS
/// implementation in MainFlutterWindow.swift. Streams a bundled asset (e.g.
/// the offline AI model) out of the app bundle into the portable Nuvok
/// library in 1MB chunks, so a ~500MB file never lands whole in RAM (iOS
/// jetsam kills apps that spike memory). Verifies size + SHA-256 before the
/// atomic rename into place, exactly like Android/macOS.
enum BundledAssetsBridge {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "nuvok/bundled_assets", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "copyAsset" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        guard let args = call.arguments as? [String: Any],
              let asset = args["asset"] as? String,
              let dest = args["dest"] as? String,
              let bytesNumber = args["bytes"] as? NSNumber,
              let sha256 = args["sha256"] as? String else {
          throw BundledAssetError.invalidArguments
        }
        try copyBundledAsset(
          asset: asset,
          destPath: dest,
          expectedBytes: bytesNumber.int64Value,
          expectedSha256: sha256)
        result(true)
      } catch {
        result(FlutterError(
          code: "COPY_ASSET_FAILED",
          message: String(describing: error),
          details: nil))
      }
    }
  }

  private static func copyBundledAsset(
    asset: String,
    destPath: String,
    expectedBytes: Int64,
    expectedSha256: String
  ) throws {
    guard asset.hasPrefix("assets/bundled_library/") else {
      throw BundledAssetError.unsafeAsset(asset)
    }
    guard !asset.split(separator: "/").contains("..") else {
      throw BundledAssetError.unsafeAsset(asset)
    }
    guard !destPath.contains("..") else {
      throw BundledAssetError.unsafeDestination(destPath)
    }
    let destination = URL(fileURLWithPath: destPath)
    let fm = FileManager.default
    try fm.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true)

    // Already installed and intact: nothing to do (idempotent seeding).
    if let attrs = try? fm.attributesOfItem(atPath: destination.path),
       let size = attrs[.size] as? NSNumber,
       size.int64Value == expectedBytes,
       let existingSha = try? sha256OfFile(destination),
       existingSha.lowercased() == expectedSha256.lowercased() {
      return
    }

    let source = try bundledAssetURL(asset)
    let tmp = URL(fileURLWithPath: destination.path + ".tmp")
    if fm.fileExists(atPath: tmp.path) {
      try fm.removeItem(at: tmp)
    }

    guard let input = InputStream(url: source) else {
      throw BundledAssetError.openFailed(source.path)
    }
    guard fm.createFile(atPath: tmp.path, contents: nil),
          let output = OutputStream(url: tmp, append: false) else {
      throw BundledAssetError.openFailed(tmp.path)
    }

    input.open()
    output.open()
    defer {
      input.close()
      output.close()
    }

    var hasher = SHA256()
    var written: Int64 = 0
    let bufferSize = 1024 * 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while input.hasBytesAvailable {
      let read = input.read(buffer, maxLength: bufferSize)
      if read < 0 {
        throw input.streamError ?? BundledAssetError.readFailed(source.path)
      }
      if read == 0 { break }
      hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: read))
      var offset = 0
      while offset < read {
        let count = output.write(buffer.advanced(by: offset), maxLength: read - offset)
        if count <= 0 {
          throw output.streamError ?? BundledAssetError.writeFailed(tmp.path)
        }
        offset += count
      }
      written += Int64(read)
    }

    guard written == expectedBytes else {
      try? fm.removeItem(at: tmp)
      throw BundledAssetError.sizeMismatch(written, expectedBytes)
    }
    let actualSha = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    guard actualSha.lowercased() == expectedSha256.lowercased() else {
      try? fm.removeItem(at: tmp)
      throw BundledAssetError.checksumMismatch(asset)
    }

    if fm.fileExists(atPath: destination.path) {
      try fm.removeItem(at: destination)
    }
    try fm.moveItem(at: tmp, to: destination)
  }

  /// Resolve a `assets/bundled_library/...` key to the real file inside the
  /// installed app. On iOS the Flutter assets live in the App.framework, so
  /// that path is tried first; the others cover engine/layout variations.
  private static func bundledAssetURL(_ asset: String) throws -> URL {
    var candidates: [URL] = []
    if let frameworks = Bundle.main.privateFrameworksURL {
      candidates.append(
        frameworks
          .appendingPathComponent("App.framework/flutter_assets/")
          .appendingPathComponent(asset))
    }
    let lookupKey = FlutterDartProject.lookupKey(forAsset: asset)
    if let mainPath = Bundle.main.path(forResource: lookupKey, ofType: nil) {
      candidates.append(URL(fileURLWithPath: mainPath))
    }
    if let resources = Bundle.main.resourceURL {
      candidates.append(
        resources.appendingPathComponent("flutter_assets/").appendingPathComponent(asset))
      candidates.append(resources.appendingPathComponent(lookupKey))
      // Recursos XL (p.ej. el modelo Gemma 4 de 3.4GB): van como recurso
      // nativo del bundle — NO como asset de Flutter, porque el empaquetado
      // de assets de Android no soporta archivos >2GB y los assets de
      // pubspec son globales. Aterrizan en la raíz de Resources con su
      // nombre de archivo.
      candidates.append(resources.appendingPathComponent(
        URL(fileURLWithPath: asset).lastPathComponent))
    }
    for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
      return candidate
    }
    throw BundledAssetError.assetNotFound(asset)
  }

  private static func sha256OfFile(_ url: URL) throws -> String {
    guard let input = InputStream(url: url) else {
      throw BundledAssetError.openFailed(url.path)
    }
    input.open()
    defer { input.close() }

    var hasher = SHA256()
    let bufferSize = 1024 * 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while input.hasBytesAvailable {
      let read = input.read(buffer, maxLength: bufferSize)
      if read < 0 {
        throw input.streamError ?? BundledAssetError.readFailed(url.path)
      }
      if read == 0 { break }
      hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: read))
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }
}

enum BundledAssetError: Error, CustomStringConvertible {
  case invalidArguments
  case unsafeAsset(String)
  case unsafeDestination(String)
  case assetNotFound(String)
  case openFailed(String)
  case readFailed(String)
  case writeFailed(String)
  case sizeMismatch(Int64, Int64)
  case checksumMismatch(String)

  var description: String {
    switch self {
    case .invalidArguments:
      return "argumentos inválidos"
    case .unsafeAsset(let value):
      return "asset fuera del bundle: \(value)"
    case .unsafeDestination(let value):
      return "destino inseguro: \(value)"
    case .assetNotFound(let value):
      return "asset no encontrado: \(value)"
    case .openFailed(let value):
      return "no se pudo abrir: \(value)"
    case .readFailed(let value):
      return "no se pudo leer: \(value)"
    case .writeFailed(let value):
      return "no se pudo escribir: \(value)"
    case .sizeMismatch(let actual, let expected):
      return "tamaño inesperado \(actual) != \(expected)"
    case .checksumMismatch(let value):
      return "checksum inválido: \(value)"
    }
  }
}
