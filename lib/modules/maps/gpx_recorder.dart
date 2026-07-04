// GPX Track Recorder — records GPS tracks for emergency navigation.
// Records position stream to a track, then exports as GPX 1.1 for use
// in external GPS apps, Garmin, etc.
//
// GPX format is XML and fully offline-compatible.
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/prepper_library.dart';
import 'location_service.dart';

/// A single track point with timestamp.
class TrackPoint {
  final double lat;
  final double lon;
  final double? elevation; // meters
  final DateTime time;

  const TrackPoint({
    required this.lat,
    required this.lon,
    this.elevation,
    required this.time,
  });

  /// Parse from Geolocator Position.
  factory TrackPoint.fromPosition(Position p) {
    return TrackPoint(
      lat: p.latitude,
      lon: p.longitude,
      elevation: p.altitude,
      time: p.timestamp,
    );
  }

  /// Convert to GPX "trkpt" XML element.
  String toGpx() {
    final ele = elevation != null ? '\n    <ele>${elevation!.toStringAsFixed(1)}</ele>' : '';
    return '<trkpt lat="$lat" lon="$lon">$ele\n    <time>${time.toIso8601String()}</time>\n  </trkpt>';
  }
}

/// A recorded GPS track.
class GpxTrack {
  final String name;
  final DateTime startTime;
  final List<TrackPoint> points;

  const GpxTrack({
    required this.name,
    required this.startTime,
    required this.points,
  });

  /// Convert to full GPX 1.1 document.
  String toGpx() {
    final pts = points.map((p) => p.toGpx()).join('\n');
    return '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Prepper Pad"
  xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>$name</name>
    <time>${startTime.toIso8601String()}</time>
  </metadata>
  <trk>
    <name>$name</name>
    <trkseg>
$pts
    </trkseg>
  </trk>
</gpx>''';
  }

  /// Distance in meters (sum of segments).
  double get distanceMeters {
    if (points.length < 2) return 0;
    double total = 0;
    for (var i = 1; i < points.length; i++) {
      total += LocationService.distanceMeters(
        points[i-1].lat, points[i-1].lon,
        points[i].lat, points[i].lon,
      );
    }
    return total;
  }

  /// Duration.
  Duration get duration => points.isNotEmpty
      ? points.last.time.difference(startTime)
      : Duration.zero;
}

/// GPX recorder that listens to location stream.
class GpxRecorder {
  static GpxRecorder? _instance;
  GpxRecorder._();

  static GpxRecorder get instance {
    _instance ??= GpxRecorder._();
    return _instance!;
  }

  bool _isRecording = false;
  String? _currentName;
  final List<TrackPoint> _points = <TrackPoint>[];
  StreamSubscription<Position>? _subscription;
  DateTime? _startTime;

  bool get isRecording => _isRecording;
  List<TrackPoint> get points => List.unmodifiable(_points);
  String? get currentName => _currentName;

  /// Start recording a new track.
  Future<bool> startRecording({String? name}) async {
    if (_isRecording) return false;

    final status = await LocationService.ensurePermission();
    if (status != LocationStatus.ok) return false;

    _currentName = name ?? 'Track ${DateTime.now().toIso8601String().substring(0, 10)}';
    _points.clear();
    _startTime = DateTime.now();
    _isRecording = true;

    // Listen to location updates
    _subscription = LocationService.stream(distanceFilterMeters: 5).listen(
      (pos) {
        if (_isRecording) {
          _points.add(TrackPoint.fromPosition(pos));
        }
      },
      onError: (_) {
        // Continue silently on GPS errors
      },
    );

    return true;
  }

  /// Stop recording and return the track.
  GpxTrack? stopRecording() {
    if (!_isRecording) return null;

    _subscription?.cancel();
    _subscription = null;
    _isRecording = false;

    if (_points.isEmpty || _startTime == null) return null;

    return GpxTrack(
      name: _currentName!,
      startTime: _startTime!,
      points: List.from(_points),
    );
  }

  /// Save track to library as .gpx file.
  Future<File?> saveTrack(GpxTrack track) async {
    final lib = PrepperLibrary.instance;
    final gpxDir = Directory('${lib.root.path}/tracks');
    if (!await gpxDir.exists()) {
      await gpxDir.create(recursive: true);
    }

    final safeName = track.name.replaceAll(RegExp(r'[^\w\-]'), '_');
    final file = File('${gpxDir.path}/$safeName.gpx');
    await file.writeAsString(track.toGpx());
    return file;
  }

  /// List all saved tracks.
  Future<List<File>> listSavedTracks() async {
    final lib = PrepperLibrary.instance;
    final gpxDir = Directory('${lib.root.path}/tracks');
    if (!await gpxDir.exists()) return [];

    final files = await gpxDir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.gpx'))
        .toList();
  }

  /// Delete a saved track.
  Future<void> deleteTrack(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Widget for recording controls.
class GpxRecorderWidget extends StatefulWidget {
  const GpxRecorderWidget({super.key});

  @override
  State<GpxRecorderWidget> createState() => _GpxRecorderWidgetState();
}

class _GpxRecorderWidgetState extends State<GpxRecorderWidget> {
  final _recorder = GpxRecorder.instance;
  bool _recording = false;
  int _pointCount = 0;

  @override
  void initState() {
    super.initState();
    _recording = _recorder.isRecording;
    _pointCount = _recorder.points.length;
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final track = _recorder.stopRecording();
      if (track != null) {
        final file = await _recorder.saveTrack(track);
        if (mounted && file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Track guardado: ${track.name}\n'
                  '${track.distanceMeters.round()}m, ${track.duration.inMinutes}min'),
            ),
          );
        }
      }
    } else {
      final ok = await _recorder.startRecording();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar GPS')),
        );
      }
    }
    setState(() {
      _recording = _recorder.isRecording;
      _pointCount = _recorder.points.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _recording ? Icons.fiber_manual_record : Icons.play_arrow,
              color: _recording ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recording ? 'Grabando track GPS...' : 'GPS Track',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _recording ? '$_pointCount puntos' : 'Graba tu ruta para exportarla',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _toggleRecording,
              icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
              label: Text(_recording ? 'Parar' : 'Grabar'),
              style: FilledButton.styleFrom(
                backgroundColor: _recording ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
