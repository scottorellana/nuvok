import CoreLocation
import Flutter
import UIKit

/// iPhone compass bridge (mirror of Android's CompassStreamHandler in
/// MainActivity.kt). Speaks the exact same channel protocol so the Dart
/// CompassService is one code path everywhere:
///   MethodChannel "nuvok/sensors":         hasCompass / hasMagnetometer /
///                                            calibrateCompass
///   EventChannel  "nuvok/sensors/compass": {heading, accuracy,
///                                            needsCalibration, sensorType,
///                                            timestampNanos}
///
/// Uses CLLocationManager heading updates — the canonical iOS compass API.
/// Magnetic heading needs NO location permission, so the compass works even
/// if the user denied location. When Core Location happens to know true
/// north (location authorized elsewhere in the app), we prefer it.
class CompassBridge: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
    private var sink: FlutterEventSink?
    private var manager: CLLocationManager?
    private var isCalibrating = false
    private var calibrationSamples = 0

    static func register(messenger: FlutterBinaryMessenger) {
        let bridge = CompassBridge()
        let methods = FlutterMethodChannel(
            name: "nuvok/sensors", binaryMessenger: messenger)
        methods.setMethodCallHandler { call, result in
            switch call.method {
            case "hasCompass", "hasMagnetometer":
                result(CLLocationManager.headingAvailable())
            case "calibrateCompass":
                bridge.isCalibrating = true
                bridge.calibrationSamples = 0
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        let events = FlutterEventChannel(
            name: "nuvok/sensors/compass", binaryMessenger: messenger)
        events.setStreamHandler(bridge)
    }

    // MARK: - FlutterStreamHandler

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        guard CLLocationManager.headingAvailable() else {
            return FlutterError(
                code: "NO_COMPASS",
                message: "Este dispositivo no expone brújula",
                details: nil)
        }
        sink = events
        let m = CLLocationManager()
        m.delegate = self
        m.headingFilter = 1 // degrees — keep the bridge quiet when still
        m.headingOrientation = Self.currentHeadingOrientation()
        m.startUpdatingHeading()
        manager = m

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(
            self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        manager?.stopUpdatingHeading()
        manager?.delegate = nil
        manager = nil
        sink = nil
        isCalibrating = false
        calibrationSamples = 0
        return nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(
        _ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading
    ) {
        guard let sink else { return }
        // magneticHeading < 0 means Core Location has no valid reading yet.
        let heading = newHeading.trueHeading >= 0
            ? newHeading.trueHeading
            : newHeading.magneticHeading
        guard heading >= 0 else { return }

        // headingAccuracy < 0 means the reading is unreliable (needs
        // calibration); mirror Android's SENSOR_STATUS_UNRELIABLE → 90°.
        let accuracyDegrees = newHeading.headingAccuracy >= 0
            ? newHeading.headingAccuracy
            : 90.0

        // Same auto-calibration convergence rule as the Android bridge.
        let effectiveNeedsCalibration: Bool
        if isCalibrating {
            calibrationSamples += 1
            if calibrationSamples > 8 && accuracyDegrees <= 10.0 {
                isCalibrating = false
            }
            effectiveNeedsCalibration =
                accuracyDegrees > 10 || calibrationSamples < 6
        } else {
            effectiveNeedsCalibration = accuracyDegrees > 10
        }

        sink([
            "heading": heading,
            "accuracy": accuracyDegrees,
            "needsCalibration": effectiveNeedsCalibration,
            "sensorType": newHeading.trueHeading >= 0
                ? "core_location_true"
                : "core_location_magnetic",
            "timestampNanos": Int64(
                newHeading.timestamp.timeIntervalSince1970 * 1_000_000_000),
        ])
    }

    func locationManagerShouldDisplayHeadingCalibration(
        _ manager: CLLocationManager
    ) -> Bool {
        // The app has its own calibration UX; show the system figure-eight
        // overlay only while the user explicitly asked to calibrate.
        return isCalibrating
    }

    // MARK: - Device orientation

    @objc private func orientationChanged() {
        manager?.headingOrientation = Self.currentHeadingOrientation()
    }

    private static func currentHeadingOrientation() -> CLDeviceOrientation {
        // faceUp/faceDown/unknown would break the heading math — keep the
        // last flat-plane orientation (default portrait) in those cases.
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .portrait
        }
    }
}
