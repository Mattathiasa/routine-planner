import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_motion.dart';

const _diameter = 48.0;
const _radius = 19.0;
const _strokeWidth = 5.0;

/// The Planner target cards' small "% of materials in hand" ring. A
/// second, smaller instance of the same ring-drawing technique as the
/// Resin screen's 220px ring — not a shared/refactored painter, to avoid
/// touching that already-shipped screen.
class PercentRingGauge extends StatelessWidget {
  const PercentRingGauge({
    super.key,
    required this.percent,
    required this.semanticLabel,
  });

  final int percent;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fraction = (percent / 100).clamp(0.0, 1.0);

    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: _diameter,
        height: _diameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: AppMotion.of(context),
              curve: AppMotion.curve,
              builder: (context, animatedFraction, _) => CustomPaint(
                size: const Size(_diameter, _diameter),
                painter: _RingPainter(
                  fraction: animatedFraction,
                  trackColor: context.colors.primaryContainer,
                  progressColor: context.colors.primary,
                ),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                '$percent%',
                style: AppDisplayNumbers.gaugePercent(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.trackColor,
    required this.progressColor,
  });

  final double fraction;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawCircle(center, _radius, trackPaint);

    if (fraction > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: _radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
