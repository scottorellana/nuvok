// Punto de encuentro familiar: quién llegó y quién falta. Puro y testeable —
// la UI solo pinta el resultado.
import 'package:latlong2/latlong.dart';

import '../mesh/position_store.dart';
import 'map_overlays.dart';

/// Radio de "ya llegó": GPS de teléfono en exteriores anda en 5-20 m; 75 m
/// tolera el error de ambos lados sin dar falsos positivos de una cuadra.
const double meetingArrivalRadiusM = 75;

/// El primer punto de reunión marcado en el mapa (compartido por mesh), o
/// null si la familia aún no definió uno.
MapOverlay? activeMeetingPoint(List<MapOverlay> overlays) {
  for (final o in overlays) {
    if (o.kind == OverlayKind.meetingPoint) return o;
  }
  return null;
}

/// Divide las posiciones vivas del grupo entre llegados y faltantes.
({List<PeerPosition> arrived, List<PeerPosition> pending}) meetingStatus(
  MapOverlay point,
  List<PeerPosition> positions, {
  double radiusM = meetingArrivalRadiusM,
}) {
  const d = Distance();
  final arrived = <PeerPosition>[];
  final pending = <PeerPosition>[];
  for (final p in positions) {
    final meters = d.as(
        LengthUnit.Meter, point.anchor, LatLng(p.lat, p.lon));
    (meters <= radiusM ? arrived : pending).add(p);
  }
  return (arrived: arrived, pending: pending);
}
