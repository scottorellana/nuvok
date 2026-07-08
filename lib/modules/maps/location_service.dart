// GPS location for the offline map. Wraps geolocator with clear, Spanish
// error states so the map UI can guide the user (services off, permission
// denied) instead of failing silently. Works fully offline — GPS needs no
// internet, only the device's own location hardware.
import 'package:geolocator/geolocator.dart';

enum LocationStatus {
  ok,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationResult {
  LocationResult(this.status, [this.position]);
  final LocationStatus status;
  final Position? position;

  bool get isOk => status == LocationStatus.ok && position != null;

  /// A user-facing message in Spanish for non-ok states.
  String get message {
    switch (status) {
      case LocationStatus.servicesDisabled:
        return 'La ubicación (GPS) está apagada en el dispositivo. '
            'Actívala en los ajustes del sistema.';
      case LocationStatus.permissionDenied:
        return 'Permiso de ubicación denegado. Concédelo para verte en '
            'el mapa.';
      case LocationStatus.permissionDeniedForever:
        return 'El permiso de ubicación está bloqueado. Actívalo a mano en '
            'los ajustes del sistema para esta app.';
      case LocationStatus.unavailable:
        return 'No se pudo obtener la ubicación en este dispositivo.';
      case LocationStatus.ok:
        return '';
    }
  }
}

class LocationService {
  /// Ensures location services are on and permission is granted, prompting
  /// the user if needed. Returns the resolved status.
  static Future<LocationStatus> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationStatus.servicesDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        return LocationStatus.permissionDenied;
      case LocationPermission.deniedForever:
        return LocationStatus.permissionDeniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationStatus.ok;
      case LocationPermission.unableToDetermine:
        return LocationStatus.unavailable;
    }
  }

  /// One-shot high-accuracy fix.
  static Future<LocationResult> current() async {
    final status = await ensurePermission();
    if (status != LocationStatus.ok) return LocationResult(status);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult(LocationStatus.ok, pos);
    } catch (_) {
      return LocationResult(LocationStatus.unavailable);
    }
  }

  /// Continuous position stream for follow mode. Emits whenever the device
  /// moves more than [distanceFilterMeters].
  static Stream<Position> stream({int distanceFilterMeters = 5}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }

  /// Straight-line distance in meters between two points.
  static double distanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Initial compass bearing (degrees) from point 1 toward point 2.
  static double bearing(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  }
}
