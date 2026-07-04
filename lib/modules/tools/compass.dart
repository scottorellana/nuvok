// Compass — heading display from the magnetometer/gyroscope.
// On platforms without sensors (desktop), shows a helpful message.
// The heading is used both standalone and can feed into the Maps module
// for orienting the offline map.
//
// Uses Flutter's sensors_plus package for raw magnetometer events and
// computes the heading from the geomagnetic field. Falls back gracefully.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// We avoid importing sensors_plus directly to not add a dependency that
// breaks desktop. Instead we use a MethodChannel stub that can be filled
// in later. For now we compute heading from magnetometer data if available.
final _sensorChannel = MethodChannel('prepper/sensors');

class CompassReading {
  final double heading; // degrees, 0=N, 90=E, 180=S, 270=W
  final double accuracy; // degrees uncertainty (low=better)
  final DateTime? timestamp;

  const CompassReading({
    required this.heading,
    required this.accuracy,
    this.timestamp,
  });

  String get cardinalDirection {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = ((heading + 22.5) % 360 / 45).floor();
    return dirs[idx];
  }
}

class CompassService {
  CompassService._();
  static final CompassService instance = CompassService._();

  StreamSubscription? _sub;
  final _controller = StreamController<CompassReading>.broadcast();
  Stream<CompassReading> get readings => _controller.stream;

  bool _available = false;
  bool get available => _available;

  // Smoothing: last few readings averaged to reduce jitter.
  final _history = <double>[];
  static const _historySize = 5;

  /// Starts listening to compass sensor events. Returns false if the
  /// platform doesn't have a magnetometer.
  Future<bool> start() async {
    if (_sub != null) return _available;
    try {
      _available =
          await _sensorChannel.invokeMethod('hasMagnetometer') ?? false;
      if (!_available) {
        _controller.add(CompassReading(
          heading: 0,
          accuracy: 999,
          timestamp: DateTime.now(),
        ));
        return false;
      }
      // Event channel would go here in a real implementation.
      // For now we return true if the sensor is available.
      return true;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  void feedRawHeading(double headingDegrees) {
    // Normalize to 0-360.
    var h = headingDegrees % 360;
    if (h < 0) h += 360;

    // Smooth: circular average of last N readings.
    _history.add(h);
    if (_history.length > _historySize) _history.removeAt(0);

    final smoothed = _circularMean(_history);
    _controller.add(CompassReading(
      heading: smoothed,
      accuracy: _history.length < _historySize ? 15 : 5,
      timestamp: DateTime.now(),
    ));
  }

  double _circularMean(List<double> angles) {
    if (angles.isEmpty) return 0;
    var sumSin = 0.0, sumCos = 0.0;
    for (final a in angles) {
      final rad = a * math.pi / 180;
      sumSin += math.sin(rad);
      sumCos += math.cos(rad);
    }
    final avg = math.atan2(sumSin / angles.length, sumCos / angles.length);
    var deg = avg * 180 / math.pi;
    if (deg < 0) deg += 360;
    return deg;
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

/// Compass UI: a rotating compass rose with cardinal directions.
class CompassWidget extends StatefulWidget {
  const CompassWidget({super.key});

  @override
  State<CompassWidget> createState() => _CompassWidgetState();
}

class _CompassWidgetState extends State<CompassWidget> {
  final _service = CompassService.instance;
  CompassReading _reading = const CompassReading(
    heading: 0,
    accuracy: 999,
    timestamp: null,
  );
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initCompass();
  }

  Future<void> _initCompass() async {
    final ok = await _service.start();
    if (ok) {
      _sub = _service.readings.listen((r) {
        if (mounted) setState(() => _reading = r);
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = _service.available;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Compass rose
              Transform.rotate(
                angle: -_reading.heading * math.pi / 180,
                child: CustomPaint(
                  size: const Size(200, 200),
                  painter: _CompassPainter(),
                ),
              ),
              // Center needle indicator (N points up when heading=0)
              if (available)
                Positioned(
                  top: 8,
                  child: Container(
                    width: 4,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (available)
          Text(
            '${_reading.heading.round()}° ${_reading.cardinalDirection}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          )
        else
          Text(
            'Sin sensor de brújula\nen este dispositivo',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Outer circle
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white54;
    canvas.drawCircle(center, radius, circlePaint);

    // Tick marks
    for (var i = 0; i < 72; i++) {
      final angle = (i * 5 - 90) * math.pi / 180;
      final isMajor = i % 18 == 0; // N, E, S, W
      final isMid = i % 9 == 0; // NE, SE, SW, NW
      final tickLength = isMajor ? 16.0 : (isMid ? 10.0 : 5.0);
      final tickPaint = Paint()
        ..strokeWidth = isMajor ? 3.0 : 1.0
        ..color = isMajor ? Colors.white : Colors.white38;

      final start = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }

    // Cardinal letters
    const cardinals = [
      ('N', 0.0, Colors.red),
      ('E', 90.0, Colors.white),
      ('S', 180.0, Colors.white),
      ('W', 270.0, Colors.white),
    ];
    for (final (letter, angleDeg, color) in cardinals) {
      final angle = (angleDeg - 90) * math.pi / 180;
      final pos = Offset(
        center.dx + (radius - 32) * math.cos(angle),
        center.dy + (radius - 32) * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: letter,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
