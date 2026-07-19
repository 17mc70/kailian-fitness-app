import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/kl_theme.dart';

/// Apple-style activity ring with one or more segments.
class KLActivityRing extends StatelessWidget {
  final double progress;
  final double size;
  final double lineWidth;
  final Color? color;
  final Widget? center;

  const KLActivityRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.lineWidth = 12,
    this.color,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final ringColor = color ?? colors.primaryAccent;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              color: ringColor,
              backgroundColor: ringColor.withValues(alpha: 0.1),
              lineWidth: lineWidth,
            ),
          ),
          ?center,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double lineWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - lineWidth) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    final foregroundPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final rect = Rect.fromCenter(center: center, width: radius * 2, height: radius * 2);
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.lineWidth != lineWidth;
}
