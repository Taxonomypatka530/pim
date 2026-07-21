import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An animated radar: static range rings, a rotating sweep, expanding pulses
/// and a glowing center. Signals "actively scanning the network".
class RadarPulse extends StatefulWidget {
  const RadarPulse({
    super.key,
    this.size = 160,
    required this.color,
    this.icon = Icons.wifi_tethering_rounded,
  });

  final double size;
  final Color color;
  final IconData icon;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_pulse, _sweep]),
            builder: (context, _) {
              return CustomPaint(
                size: Size.square(widget.size),
                painter: _RadarPainter(
                  pulse: _pulse.value,
                  sweep: _sweep.value,
                  color: widget.color,
                ),
              );
            },
          ),
          Container(
            width: widget.size * 0.28,
            height: widget.size * 0.28,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: widget.size * 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.pulse,
    required this.sweep,
    required this.color,
  });

  final double pulse;
  final double sweep;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Static range rings.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.16);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * i / 3, ringPaint);
    }

    // Rotating sweep sector.
    final sweepAngle = sweep * 2 * math.pi;
    final rect = Rect.fromCircle(center: center, radius: maxRadius);
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi / 2,
      colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.0)],
      transform: GradientRotation(sweepAngle),
    );
    final sweepPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Expanding pulse rings (three, staggered).
    for (var i = 0; i < 3; i++) {
      final t = (pulse + i / 3) % 1.0;
      final radius = maxRadius * t;
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - t) * 0.5);
      canvas.drawCircle(center, radius, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.pulse != pulse || old.sweep != sweep || old.color != color;
}
