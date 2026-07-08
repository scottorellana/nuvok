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
import '../../core/locale_service.dart';

// We avoid importing sensors_plus directly to keep desktop builds stable.
// Android/macOS provide capability checks through MethodChannel and Android
// streams continuous headings through the native EventChannel below.
final _sensorChannel = MethodChannel('prepper/sensors');
final _compassEventChannel = EventChannel('prepper/sensors/compass');

class CompassMath {
  const CompassMath._();

  static double normalizeHeading(double headingDegrees) {
    var h = headingDegrees % 360;
    if (h < 0) h += 360;
    // Avoid showing 360° due to floating point dust; north is 0°.
    return h == 360 ? 0 : h;
  }

  static double circularMean(Iterable<double> angles) {
    final list = angles.toList(growable: false);
    if (list.isEmpty) return 0;
    var sumSin = 0.0, sumCos = 0.0;
    for (final a in list) {
      final rad = normalizeHeading(a) * math.pi / 180;
      sumSin += math.sin(rad);
      sumCos += math.cos(rad);
    }
    if (sumSin.abs() < 1e-12 && sumCos.abs() < 1e-12) return 0;
    final avg = math.atan2(sumSin / list.length, sumCos / list.length);
    return normalizeHeading(avg * 180 / math.pi);
  }

  static String cardinalDirection(double heading) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = ((normalizeHeading(heading) + 22.5) % 360 / 45).floor();
    return dirs[idx];
  }
}

class CompassReading {
  final double heading; // degrees, 0=N, 90=E, 180=S, 270=W
  final double accuracy; // degrees uncertainty (low=better)
  final bool needsCalibration;
  final String? sensorType;
  final DateTime? timestamp;

  const CompassReading({
    required this.heading,
    required this.accuracy,
    this.needsCalibration = false,
    this.sensorType,
    this.timestamp,
  });

  String get cardinalDirection => CompassMath.cardinalDirection(heading);
}

class CompassService extends ChangeNotifier {
  CompassService._();
  static final CompassService instance = CompassService._();

  /// Test-only constructor used by `test/compass_test.dart`. The test file
  /// calls `CompassService.createForTest()` directly — never executed in
  /// production paths.
  @visibleForTesting
  factory CompassService.createForTest() = CompassService._;

  StreamSubscription? _sub;
  final _controller = StreamController<CompassReading>.broadcast();
  Stream<CompassReading> get readings => _controller.stream;

  bool _available = false;
  bool get available => _available;

  bool _isCalibrating = false;
  bool get isCalibrating => _isCalibrating;

  Timer? _calibrationTimer;

  // Smoothing: last few readings averaged to reduce jitter.
  final _history = <double>[];
  static const _historySize = 5;

  /// Starts listening to compass sensor events. Returns false if the
  /// platform doesn't have a usable heading sensor.
  Future<bool> start() async {
    if (_sub != null) {
      if (_available && !_isCalibrating) {
        unawaited(calibrate());
      }
      return _available;
    }

    try {
      final rotationVector = await _sensorChannel.invokeMethod<bool>(
        'hasCompass',
      );
      final magnetometer = await _sensorChannel.invokeMethod<bool>(
        'hasMagnetometer',
      );
      final hasCompass = (rotationVector ?? false) || (magnetometer ?? false);
      _available = hasCompass;
      _history.clear();
      if (!_available) {
        // Don't emit a fake "heading=0°" reading into the public stream. In a
        // survival app the UI would otherwise show "north" with the same
        // widget as a real reading, silently guiding the user wrong. The UI
        // already renders an "unavailable" state from `instance.available`.
        notifyListeners();
        return false;
      }

      _sub = _compassEventChannel.receiveBroadcastStream().listen(
        _onNativeReading,
        onError: (_) {
          _sub?.cancel();
          _sub = null;
          _available = false;
          _isCalibrating = false;
          _calibrationTimer?.cancel();
          _calibrationTimer = null;
          // Same reasoning as above — don't emit a fake reading. Just mark
          // unavailable so the UI falls back to its "no compass" state.
          notifyListeners();
        },
      );
      unawaited(calibrate());
      return true;
    } catch (_) {
      _available = false;
      _isCalibrating = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> calibrate({Duration? duration}) async {
    if (!_available) return;
    duration ??= const Duration(seconds: 4);

    _calibrationTimer?.cancel();
    _history.clear();
    _isCalibrating = true;
    notifyListeners();
    try {
      await _sensorChannel.invokeMethod<void>('calibrateCompass');
    } catch (_) {
      // Native side may not expose calibration yet; keep local reset as fallback.
    }

    _calibrationTimer = Timer(duration, () {
      _isCalibrating = false;
      notifyListeners();
    });
  }

  void _onNativeReading(Object? event) {
    if (event is num) {
      feedRawHeading(event.toDouble());
      return;
    }
    if (event is Map) {
      final heading = event['heading'];
      if (heading is num) {
        final accuracy = event['accuracy'];
        final needsCalibration = event['needsCalibration'];
        final sensorType = event['sensorType'];
        feedRawHeading(
          heading.toDouble(),
          accuracyDegrees: accuracy is num ? accuracy.toDouble() : null,
          needsCalibration: needsCalibration is bool ? needsCalibration : false,
          sensorType: sensorType is String ? sensorType : null,
        );
      }
    }
  }

  void feedRawHeading(
    double headingDegrees, {
    double? accuracyDegrees,
    bool needsCalibration = false,
    String? sensorType,
  }) {
    if (!headingDegrees.isFinite) return;
    final h = CompassMath.normalizeHeading(headingDegrees);

    // Smooth: circular average of last N readings.
    _history.add(h);
    if (_history.length > _historySize) _history.removeAt(0);

    final effectiveNeedsCalibration = _isCalibrating || needsCalibration;
    final smoothed = CompassMath.circularMean(_history);
    _controller.add(CompassReading(
      heading: smoothed,
      accuracy: accuracyDegrees ?? (_history.length < _historySize ? 15 : 5),
      needsCalibration: effectiveNeedsCalibration,
      sensorType: sensorType,
      timestamp: DateTime.now(),
    ));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _isCalibrating = false;
    _calibrationTimer?.cancel();
    _calibrationTimer = null;
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _controller.close();
    super.dispose();
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
    needsCalibration: false,
    timestamp: null,
  );
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _initCompass();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
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

  Future<void> _calibrateNow() async {
    await _service.calibrate();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service.removeListener(_onServiceChanged);
    _service.stop();
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
          Column(
            children: [
              Text(
                '${_reading.heading.round()}° ${_reading.cardinalDirection}',
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _reading.needsCalibration
                    ? 'Precisión baja · calibrando automáticamente'
                    : 'Precisión ±${_reading.accuracy.round()}°',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _reading.needsCalibration
                      ? Colors.orangeAccent
                      : Theme.of(context).hintColor,
                  fontSize: 14,
                  fontWeight: _reading.needsCalibration
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 8),
              if (_service.isCalibrating)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Calibrando brújula…', style: TextStyle(fontSize: 13)),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: _calibrateNow,
                  icon: const Icon(Icons.explore, size: 18),
                  label: Text(tr(context, 'calibrateCompass')),
                ),
            ],
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
