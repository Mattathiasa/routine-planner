import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../application/resin_controller.dart';
import '../domain/resin_engine.dart';
import 'resin_formatting.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/rolling_number.dart';
import '../../../core/widgets/app_status_views.dart';

/// The ring gauge + the "Next +1 in" / "Full at" stat tiles, in one 24px
/// white section — the ring section's own radius (24px) doesn't match
/// `AppCard`'s hard-coded 20px, so this uses a raw `DecoratedBox` directly
/// (same pattern `ResinHeroCard` already uses for its own custom radius).
class ResinRingSection extends ConsumerWidget {
  const ResinRingSection({super.key});

  static const _engine = ResinEngine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resinAsync = ref.watch(resinControllerProvider);
    final now = ref.watch(clockProvider).nowUtc();

    return resinAsync.when(
      data: (state) {
        final v = _engine.v(state, now);
        final timers = resinCapTimers(engine: _engine, state: state, now: now);
        final nextTick = timers.nextTick;
        final fullAt = timers.fullAt;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.all(Radius.circular(24)),
            boxShadow: AppShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              children: [
                _ResinRing(value: v, cap: state.cap),
                const SizedBox(height: AppSpacing.xlg),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Next +1 in',
                        value: nextTick != null
                            ? formatCountdown(nextTick.difference(now))
                            : '—',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: _StatTile(
                        label: 'Full at',
                        value: fullAt != null ? formatTime(fullAt) : '—',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(height: 320, child: AppLoadingView()),
      error: (error, stack) => AppErrorView(error: error),
    );
  }
}

class _ResinRing extends StatelessWidget {
  const _ResinRing({required this.value, required this.cap});

  final int value;
  final int cap;

  @override
  Widget build(BuildContext context) {
    final fraction = cap <= 0 ? 0.0 : (value / cap).clamp(0.0, 1.0);

    return SizedBox(
      width: 220,
      height: 220,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction),
        duration: AppMotion.of(context),
        curve: AppMotion.curve,
        builder: (context, animatedFraction, child) => CustomPaint(
          painter: _ResinRingPainter(
            fraction: animatedFraction,
            trackColor: context.colors.primaryContainer,
          ),
          child: child,
        ),
        child: Center(
          child: Semantics(
            label: '$value of $cap Original Resin',
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RollingNumber(
                    value,
                    style: AppDisplayNumbers.ringNumber(
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of $cap',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResinRingPainter extends CustomPainter {
  _ResinRingPainter({required this.fraction, required this.trackColor});

  final double fraction;
  final Color trackColor;

  static const _strokeWidth = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - _strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (fraction > 0) {
      final progressPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A77F2), Color(0xFF3B4FE0)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ResinRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.trackColor != trackColor;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.mlg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
          Text(value, style: Theme.of(context).textTheme.headlineLarge),
        ],
      ),
    );
  }
}
