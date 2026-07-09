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
    // Prepper Mesh over BLE: dual-role (advertise + scan) bridge, mirror of
    // the Android BleMeshBridge — this is what lets an iPhone find another
    // Prepper Pad with zero infrastructure.
    if let registrar =
        engineBridge.pluginRegistry.registrar(forPlugin: "PrepperBleMesh") {
      BleMeshBridge.register(messenger: registrar.messenger())
    }
    // Compass over CoreLocation: mirror of the Android CompassStreamHandler,
    // same channel protocol, so the Dart CompassService has no platform
    // branches.
    if let registrar =
        engineBridge.pluginRegistry.registrar(forPlugin: "PrepperCompass") {
      CompassBridge.register(messenger: registrar.messenger())
    }
  }
}
