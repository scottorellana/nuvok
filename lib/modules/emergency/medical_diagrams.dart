// Medical procedure diagrams — pure Flutter CustomPainter vector graphics.
// Zero image assets, zero memory overhead, infinite scalability.
// Each diagram is an animated, self-contained widget that demonstrates
// a life-saving procedure with visual clarity.
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Generic guide illustration — vector "image" for every survival/first-aid
// guide. It keeps the app offline-first and low-RAM: no raster assets, no web
// downloads, just CustomPainter shapes chosen from the guide id.
// ─────────────────────────────────────────────────────────────────────────────

class GuideVisualIllustration extends StatefulWidget {
  const GuideVisualIllustration({super.key, required this.guideId});

  final String guideId;

  @override
  State<GuideVisualIllustration> createState() =>
      _GuideVisualIllustrationState();
}

class _GuideVisualIllustrationState extends State<GuideVisualIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 170,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _GuideVisualPainter(widget.guideId, _ctrl.value),
        ),
      ),
    );
  }
}

class _GuideVisualPainter extends CustomPainter {
  _GuideVisualPainter(this.id, this.t);

  final String id;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    final danger = _dangerColor(id);
    final safe = _safeColor(id);
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [safe.withValues(alpha: 0.18), danger.withValues(alpha: 0.16)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRRect(bg, bgPaint);

    _drawPulse(canvas, size, danger);
    _drawScene(canvas, size, safe, danger);
    _drawChecklist(canvas, size, safe);
  }

  Color _dangerColor(String id) {
    if (id.contains('agua') || id.contains('water') || id.contains('flood')) {
      return Colors.blue;
    }
    if (id.contains('quemadura') || id.contains('fire') || id.contains('hur')) {
      return Colors.deepOrange;
    }
    if (id.contains('hemorragia') ||
        id.startsWith('rcp') ||
        id.contains('heart')) {
      return Colors.red;
    }
    if (id.contains('naveg') || id.contains('rescue') || id.contains('senas')) {
      return Colors.amber.shade800;
    }
    return Colors.teal;
  }

  Color _safeColor(String id) {
    if (id.contains('abrigo') || id.contains('shelter')) return Colors.brown;
    if (id.contains('botiquin') ||
        id.contains('auxilios') ||
        id.contains('aid')) {
      return Colors.green;
    }
    return Colors.blueGrey;
  }

  void _drawPulse(Canvas canvas, Size size, Color color) {
    final center = Offset(size.width * 0.22, size.height * 0.48);
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1;
      canvas.drawCircle(
        center,
        22 + phase * 32,
        Paint()
          ..color = color.withValues(alpha: (1 - phase) * 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _drawScene(Canvas canvas, Size size, Color safe, Color danger) {
    final cx = size.width * 0.24;
    final cy = size.height * 0.52;
    final person = Paint()..color = safe.withValues(alpha: 0.92);
    canvas.drawCircle(Offset(cx, cy - 28), 14, person);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 12), width: 46, height: 70),
        const Radius.circular(18),
      ),
      person,
    );

    final iconPaint = Paint()
      ..color = danger
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final x = size.width * 0.54;
    final y = size.height * 0.44;
    if (id.contains('agua') || id.contains('water') || id.contains('flood')) {
      final drop = Path()
        ..moveTo(x, y - 34)
        ..cubicTo(x - 36, y + 10, x - 14, y + 50, x, y + 50)
        ..cubicTo(x + 14, y + 50, x + 36, y + 10, x, y - 34)
        ..close();
      canvas.drawPath(drop, iconPaint);
    } else if (id.contains('naveg') ||
        id.contains('rescue') ||
        id.contains('senas')) {
      final path = Path()
        ..moveTo(x - 36, y + 42)
        ..lineTo(x, y - 42)
        ..lineTo(x + 36, y + 42)
        ..lineTo(x, y + 24)
        ..close();
      canvas.drawPath(path, iconPaint);
      canvas.drawCircle(Offset(x, y), 7 + t * 4, Paint()..color = danger);
    } else if (id.contains('abrigo') || id.contains('shelter')) {
      final roof = Path()
        ..moveTo(x - 48, y + 28)
        ..lineTo(x, y - 42)
        ..lineTo(x + 48, y + 28);
      canvas.drawPath(roof, iconPaint);
      canvas.drawLine(Offset(x - 28, y + 28), Offset(x - 28, y - 2), iconPaint);
      canvas.drawLine(Offset(x + 28, y + 28), Offset(x + 28, y - 2), iconPaint);
    } else {
      canvas.drawLine(Offset(x - 40, y), Offset(x + 40, y), iconPaint);
      canvas.drawLine(Offset(x, y - 40), Offset(x, y + 40), iconPaint);
      canvas.drawCircle(Offset(x, y), 48 + t * 4, iconPaint..strokeWidth = 3);
    }
  }

  void _drawChecklist(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.86)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final startX = size.width * 0.72;
    for (var i = 0; i < 3; i++) {
      final y = 48.0 + i * 30;
      canvas.drawLine(Offset(startX, y), Offset(startX + 10, y + 10), paint);
      canvas.drawLine(
          Offset(startX + 10, y + 10), Offset(startX + 30, y - 8), paint);
      canvas.drawLine(
          Offset(startX + 42, y), Offset(size.width - 24, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuideVisualPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.id != id;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CPR Compression Animation — shows correct hand position, depth, and rhythm
// ─────────────────────────────────────────────────────────────────────────────

class CprAnimation extends StatefulWidget {
  const CprAnimation({super.key});
  @override
  State<CprAnimation> createState() => _CprAnimationState();
}

class _CprAnimationState extends State<CprAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 110 BPM = 0.545s per compression cycle
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 545),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 280,
          height: 220,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              size: const Size(280, 220),
              painter: _CprPainter(_ctrl.value),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Depth indicator
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final depth = (_ctrl.value * 5.5).round();
            return Text(
              'Profundidad: $depth cm · 110 compresiones/min',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).hintColor,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CprPainter extends CustomPainter {
  final double t; // 0.0 = released, 1.0 = compressed
  _CprPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height - 20;

    // Ground line
    final groundPaint = Paint()
      ..color = Colors.brown.shade300
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(20, groundY),
      Offset(size.width - 20, groundY),
      groundPaint,
    );

    // Person lying down (simplified side view)
    final bodyPaint = Paint()
      ..color = Colors.blueGrey.shade300
      ..style = PaintingStyle.fill;

    // Body (torso as rounded rectangle)
    final torsoY = groundY - 50;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(40, torsoY, 180, 50),
      const Radius.circular(10),
    );
    // Offset torso by compression depth
    final compressOffset = t * 18.0; // visual exaggeration
    canvas.save();
    canvas.translate(0, compressOffset);
    canvas.drawRRect(bodyRect, bodyPaint);

    // Head (circle)
    canvas.drawCircle(
      Offset(50, torsoY + 15),
      18,
      bodyPaint,
    );

    // Sternum marker (target zone)
    final sternumPaint = Paint()
      ..color = Colors.red.shade700
      ..style = PaintingStyle.fill;
    final sternumX = 130.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(sternumX, torsoY + 8), width: 24, height: 14),
        const Radius.circular(4),
      ),
      sternumPaint,
    );

    canvas.restore();

    // Hands (on top of chest, move down with compression)
    final handY = torsoY - 5 + compressOffset;
    final handPaint = Paint()
      ..color = Colors.amber.shade600
      ..style = PaintingStyle.fill;

    // Hand 1 (palm)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(sternumX, handY), width: 30, height: 16),
        const Radius.circular(6),
      ),
      handPaint,
    );
    // Hand 2 (on top)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(sternumX, handY - 12), width: 26, height: 14),
        const Radius.circular(5),
      ),
      Paint()
        ..color = Colors.amber.shade800
        ..style = PaintingStyle.fill,
    );

    // Arms (from rescuer, straight lines)
    final armPaint = Paint()
      ..color = Colors.amber.shade700
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(sternumX, handY - 18),
      Offset(sternumX, 30),
      armPaint,
    );

    // Compression depth arrow
    final arrowPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Arrow showing depth
    final arrowX = sternumX + 35;
    canvas.drawLine(
      Offset(arrowX, torsoY),
      Offset(arrowX, torsoY + compressOffset),
      arrowPaint,
    );
    // Arrowhead
    if (compressOffset > 5) {
      final path = Path()
        ..moveTo(arrowX - 4, torsoY + compressOffset - 4)
        ..lineTo(arrowX, torsoY + compressOffset)
        ..lineTo(arrowX + 4, torsoY + compressOffset - 4);
      canvas.drawPath(path, arrowPaint..style = PaintingStyle.fill);
    }

    // Labels
    _drawLabel(canvas, 'Manos en esternón', Offset(sternumX - 30, torsoY - 35),
        Colors.red.shade700);
    _drawLabel(canvas, 'Brazos rectos', Offset(sternumX + 15, 20),
        Colors.amber.shade800);
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 120);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: pos + Offset(tp.width / 2, tp.height / 2),
            width: tp.width + 8,
            height: tp.height + 4),
        const Radius.circular(4),
      ),
      Paint()..color = color.withValues(alpha: 0.15),
    );
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _CprPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Heimlich Maneuver Animation — shows inward+upward abdominal thrust
// ─────────────────────────────────────────────────────────────────────────────

class HeimlichAnimation extends StatefulWidget {
  const HeimlichAnimation({super.key});
  @override
  State<HeimlichAnimation> createState() => _HeimlichAnimationState();
}

class _HeimlichAnimationState extends State<HeimlichAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 220,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: const Size(280, 220),
          painter: _HeimlichPainter(_ctrl.value),
        ),
      ),
    );
  }
}

class _HeimlichPainter extends CustomPainter {
  final double t;
  _HeimlichPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Victim (standing, side view)
    final victimPaint = Paint()
      ..color = Colors.blueGrey.shade300
      ..style = PaintingStyle.fill;

    // Head
    canvas.drawCircle(Offset(cx + 10, 30), 16, victimPaint);
    // Torso (tall rectangle)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 5, 46, 40, 80),
        const Radius.circular(8),
      ),
      victimPaint,
    );
    // Legs
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 5, 126, 15, 60),
        const Radius.circular(4),
      ),
      victimPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 18, 126, 15, 60),
        const Radius.circular(4),
      ),
      victimPaint,
    );

    // Navel marker
    final navelY = 95.0;
    canvas.drawCircle(
        Offset(cx + 15, navelY), 3, Paint()..color = Colors.brown.shade600);

    // Fist position (above navel, moves inward+upward on thrust)
    final thrustOffset = t * 12.0;
    final fistX = cx - 10 - thrustOffset;
    final fistY = navelY - 8 - thrustOffset;

    // Rescuer arms (reaching around)
    final armPaint = Paint()
      ..color = Colors.amber.shade700
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    // Arm going behind victim
    canvas.drawLine(
      Offset(cx - 60, 90),
      Offset(cx - 5, navelY - 5),
      armPaint,
    );
    // Arm with fist
    canvas.drawLine(
      Offset(cx + 35, 85),
      Offset(fistX + 8, fistY),
      armPaint,
    );

    // Fist
    canvas.drawCircle(
      Offset(fistX, fistY),
      10,
      Paint()..color = Colors.amber.shade800,
    );
    // Other hand gripping fist
    canvas.drawCircle(
      Offset(fistX - 8, fistY),
      8,
      Paint()..color = Colors.amber.shade600,
    );

    // Thrust direction arrow (inward + upward)
    if (t > 0.1) {
      final arrowPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final arrowStart = Offset(fistX - 25, fistY + 20);
      final arrowEnd =
          Offset(fistX - 5 - thrustOffset, fistY - 5 - thrustOffset);
      canvas.drawLine(arrowStart, arrowEnd, arrowPaint);
      // Arrowhead
      final angle = (arrowEnd - arrowStart).direction;
      final path = Path()
        ..moveTo(arrowEnd.dx, arrowEnd.dy)
        ..lineTo(
          arrowEnd.dx - 8 * math.cos(angle - 0.5),
          arrowEnd.dy - 8 * math.sin(angle - 0.5),
        )
        ..lineTo(
          arrowEnd.dx - 8 * math.cos(angle + 0.5),
          arrowEnd.dy - 8 * math.sin(angle + 0.5),
        )
        ..close();
      canvas.drawPath(path, arrowPaint..style = PaintingStyle.fill);
    }

    // Labels
    _drawLabel(canvas, 'Puño arriba\ndel ombligo', const Offset(5, 60),
        Colors.red.shade700);
    _drawLabel(canvas, 'Jala hacia\nadentro y arriba',
        Offset(size.width - 90, 160), Colors.amber.shade800);
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: pos + Offset(tp.width / 2, tp.height / 2),
            width: tp.width + 8,
            height: tp.height + 4),
        const Radius.circular(4),
      ),
      Paint()..color = color.withValues(alpha: 0.12),
    );
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _HeimlichPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tourniquet Diagram — static labeled cross-section
// ─────────────────────────────────────────────────────────────────────────────

class TourniquetDiagram extends StatelessWidget {
  const TourniquetDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 180,
      child: CustomPaint(
        size: const Size(320, 180),
        painter: _TourniquetPainter(),
      ),
    );
  }
}

class _TourniquetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Leg (horizontal cylinder)
    final legPaint = Paint()
      ..color = Colors.blueGrey.shade200
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, 60, 280, 50),
        const Radius.circular(25),
      ),
      legPaint,
    );

    // Wound (red mark)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(180, 65, 20, 40),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.red.shade700,
    );
    // Blood drops
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(190 + i * 3.0, 115 + i * 5),
        3,
        Paint()..color = Colors.red,
      );
    }

    // Tourniquet band (dark strip)
    final tqX = 120.0;
    final tqPaint = Paint()
      ..color = Colors.brown.shade800
      ..style = PaintingStyle.fill
      ..strokeWidth = 12;
    canvas.drawLine(
      Offset(tqX, 50),
      Offset(tqX, 120),
      tqPaint,
    );

    // Windlass (stick)
    final stickPaint = Paint()
      ..color = Colors.orange.shade800
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(tqX - 20, 40),
      Offset(tqX + 20, 130),
      stickPaint,
    );

    // Distance arrow (tourniquet to wound)
    final arrowPaint = Paint()
      ..color = Colors.green.shade700
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final arrowY = 140.0;
    canvas.drawLine(Offset(tqX, arrowY), Offset(180, arrowY), arrowPaint);
    // Tick marks
    canvas.drawLine(
        Offset(tqX, arrowY - 4), Offset(tqX, arrowY + 4), arrowPaint);
    canvas.drawLine(
        Offset(180, arrowY - 4), Offset(180, arrowY + 4), arrowPaint);

    // Labels
    _drawLabel(
        canvas, 'Torniquete', Offset(tqX - 35, 15), Colors.brown.shade800);
    _drawLabel(canvas, '5-8 cm arriba\nde la herida',
        Offset(tqX + 5, arrowY + 5), Colors.green.shade700);
    _drawLabel(canvas, 'Herida', Offset(185, 130), Colors.red.shade700);
    _drawLabel(canvas, 'Girar palo\n→ parar sangrado', Offset(250, 20),
        Colors.orange.shade800);
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: pos + Offset(tp.width / 2, tp.height / 2),
            width: tp.width + 8,
            height: tp.height + 4),
        const Radius.circular(4),
      ),
      Paint()..color = color.withValues(alpha: 0.12),
    );
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Recovery Position Diagram — static labeled
// ─────────────────────────────────────────────────────────────────────────────

class RecoveryPositionDiagram extends StatelessWidget {
  const RecoveryPositionDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 160,
      child: CustomPaint(
        size: const Size(320, 160),
        painter: _RecoveryPainter(),
      ),
    );
  }
}

class _RecoveryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = Colors.blueGrey.shade300
      ..style = PaintingStyle.fill;

    final groundPaint = Paint()
      ..color = Colors.brown.shade300
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(10, size.height - 15),
      Offset(size.width - 10, size.height - 15),
      groundPaint,
    );

    // Person on side (simplified)
    // Head
    canvas.drawCircle(Offset(50, size.height - 45), 18, bodyPaint);
    // Torso (angled)
    final torsoPath = Path()
      ..moveTo(65, size.height - 50)
      ..lineTo(180, size.height - 70)
      ..lineTo(185, size.height - 40)
      ..lineTo(70, size.height - 25)
      ..close();
    canvas.drawPath(torsoPath, bodyPaint);

    // Arm at right angle (near arm)
    final armPaint = Paint()
      ..color = Colors.amber.shade600
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(40, size.height - 55, 30, 12),
        const Radius.circular(6),
      ),
      armPaint,
    );

    // Hand under cheek
    canvas.drawCircle(Offset(48, size.height - 50), 6, armPaint);

    // Bent knee (far leg)
    final kneePaint = Paint()
      ..color = Colors.blueGrey.shade400
      ..style = PaintingStyle.fill;
    final kneePath = Path()
      ..moveTo(180, size.height - 55)
      ..lineTo(240, size.height - 80)
      ..lineTo(250, size.height - 65)
      ..lineTo(185, size.height - 35)
      ..close();
    canvas.drawPath(kneePath, kneePaint);

    // Labels
    _drawLabel(canvas, 'Brazo en\nángulo recto', const Offset(5, 10),
        Colors.amber.shade700);
    _drawLabel(canvas, 'Mano bajo\nla mejilla', const Offset(30, 75),
        Colors.amber.shade700);
    _drawLabel(canvas, 'Rodilla doblada\n(estabiliza)', Offset(200, 5),
        Colors.blueGrey.shade600);
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: pos + Offset(tp.width / 2, tp.height / 2),
            width: tp.width + 8,
            height: tp.height + 4),
        const Radius.circular(4),
      ),
      Paint()..color = color.withValues(alpha: 0.12),
    );
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Burn severity chart — static table-like visual
// ─────────────────────────────────────────────────────────────────────────────

class BurnSeverityChart extends StatelessWidget {
  const BurnSeverityChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clasificación de quemaduras',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _burnRow(context, '1er grado', 'Rojo, doloroso, sin ampollas',
                Colors.red.shade300, 'Ej: quemadura solar'),
            const Divider(height: 4),
            _burnRow(context, '2do grado', 'Ampollas, muy doloroso',
                Colors.orange.shade600, 'Ej: agua hirviendo'),
            const Divider(height: 4),
            _burnRow(context, '3er grado', 'Piel blanca/carbonizada, SIN dolor',
                Colors.grey.shade800, 'Ej: fuego directo'),
          ],
        ),
      ),
    );
  }

  Widget _burnRow(BuildContext context, String degree, String desc, Color color,
      String example) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(degree,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(desc,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor)),
                Text(example,
                    style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bee sting vs snake bite comparison
// ─────────────────────────────────────────────────────────────────────────────

class BiteStingComparison extends StatelessWidget {
  const BiteStingComparison({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mordedura vs Picadura — Qué hacer',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _compareRow(
                context, Icons.warning, Colors.red, 'Mordedura de serpiente', [
              '❌ NO succiones',
              '❌ NO torniquete',
              '❌ NO hielo',
              '✅ Inmoviliza, calma, traslada YA'
            ]),
            const Divider(),
            _compareRow(
                context, Icons.bug_report, Colors.orange, 'Picadura de abeja', [
              '✅ Raspa el aguijón (no pellizques)',
              '✅ Lava con agua y jabón',
              '✅ Hielo envuelto en tela',
              '✅ Antihistamínico si hay hinchazón'
            ]),
          ],
        ),
      ),
    );
  }

  Widget _compareRow(BuildContext context, IconData icon, Color color,
      String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(item, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trauma triage decision tree (START algorithm simplified)
// ─────────────────────────────────────────────────────────────────────────────

class TriageFlowchart extends StatelessWidget {
  const TriageFlowchart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Triaje — ¿Quién atender primero?',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _triageStep(context, Colors.red, 'ROJO',
                'No respira tras abrir vía aérea → RCP AHORA'),
            _arrow(context),
            _triageStep(context, Colors.orange, 'NARANJA',
                'Sangra mucho → Presión/torniquete AHORA'),
            _arrow(context),
            _triageStep(context, Colors.yellow.shade700, 'AMARILLO',
                'Respira y no sangra mucho → Inmoviliza, observa'),
            _arrow(context),
            _triageStep(context, Colors.green, 'VERDE',
                'Camina y habla → Puede esperar'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '🔵 NEGRO: No respira aunque abras la vía aérea. En '
                'emergencias con muchos heridos, prioriza a los que sí '
                'pueden salvarse.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _triageStep(
      BuildContext context, Color color, String label, String desc) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _arrow(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 2),
        child: Icon(Icons.arrow_downward,
            size: 14, color: Theme.of(context).hintColor),
      );
}
