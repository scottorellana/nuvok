import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Nuvok Link over BLE: dual-role (advertise + scan) bridge, mirror of
    // the Android BleMeshBridge — this is what lets an iPhone find another
    // Nuvok with zero infrastructure.
    if let registrar =
        engineBridge.pluginRegistry.registrar(forPlugin: "NuvokBleMesh") {
      BleMeshBridge.register(messenger: registrar.messenger())
    }
    // Compass over CoreLocation: mirror of the Android CompassStreamHandler,
    // same channel protocol, so the Dart CompassService has no platform
    // branches.
    if let registrar =
        engineBridge.pluginRegistry.registrar(forPlugin: "NuvokCompass") {
      CompassBridge.register(messenger: registrar.messenger())
    }
    // Bundled assets: streams the offline AI model out of the app bundle into
    // the portable library so the IA specialists run offline on iPhone (mirror
    // of the Android/macOS copyAsset handler).
    if let registrar =
        engineBridge.pluginRegistry.registrar(forPlugin: "NuvokBundledAssets") {
      BundledAssetsBridge.register(messenger: registrar.messenger())
    }
  }
}
