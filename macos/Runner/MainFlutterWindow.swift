import Cocoa
import CryptoKit
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let channel = FlutterMethodChannel(
      name: "nuvok/bundled_assets",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
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
        try Self.copyBundledAsset(
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

    let sensorChannel = FlutterMethodChannel(
      name: "nuvok/sensors",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    sensorChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "hasCompass", "hasMagnetometer":
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let compassEvents = FlutterEventChannel(
      name: "nuvok/sensors/compass",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    compassEvents.setStreamHandler(NoCompassStreamHandler())

    // Nuvok Link over BLE: dual-role (advertise + scan) bridge, mirror of
    // the Android BleMeshBridge so Apple↔Android pairs find each other.
    BleMeshBridge.register(
      messenger: flutterViewController.engine.binaryMessenger)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
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

  private static func bundledAssetURL(_ asset: String) throws -> URL {
    var candidates: [URL] = []
    let lookupKey = FlutterDartProject.lookupKey(forAsset: asset)
    if let resources = Bundle.main.resourceURL {
      candidates.append(resources.appendingPathComponent("flutter_assets/").appendingPathComponent(asset))
      candidates.append(resources.appendingPathComponent(lookupKey))
    }
    if let frameworks = Bundle.main.privateFrameworksURL {
      candidates.append(
        frameworks
          .appendingPathComponent("App.framework/Resources/flutter_assets/")
          .appendingPathComponent(asset))
      candidates.append(
        frameworks
          .appendingPathComponent("App.framework/Resources/")
          .appendingPathComponent(lookupKey))
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

final class NoCompassStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    events(FlutterError(
      code: "NO_COMPASS",
      message: "macOS no expone brújula/magnetómetro nativo compatible",
      details: nil))
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    return nil
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
