// Cross-module "show this on the map" request: the SOS alert dialog (shell)
// and the mesh page set it; MapsPage listens and centers the camera.
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class MapFocus {
  static final ValueNotifier<LatLng?> request = ValueNotifier(null);

  static void go(LatLng target) => request.value = target;
}
