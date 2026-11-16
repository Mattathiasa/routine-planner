import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// An integer that rolls (counts) to its new value whenever it changes,
/// odometer-style, over [AppMotion.duration]. Under reduce-motion the
/// duration is zero, so the new value just appears.
class RollingNumber extends StatelessWidget {
  const RollingNumber(this.value, {super.key, this.style});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: AppMotion.of(context),
      curve: AppMotion.curve,
      builder: (context, animated, _) => Text('${animated.round()}', style: style),
    );
  }
}
