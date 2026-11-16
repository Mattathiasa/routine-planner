import 'package:flutter/material.dart';

/// Motion tokens: one duration/curve pair for the app's micro-animations
/// (ring sweeps, number rolls, shared-element flights), all within the
/// 150–250 ms band. Every animation must size its duration via [of] so
/// the OS reduce-motion setting (surfaced as
/// [MediaQueryData.disableAnimations]) collapses it to zero.
abstract final class AppMotion {
  static const duration = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;

  static Duration of(BuildContext context) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
}

/// A [MaterialPageRoute] whose transition (and any Hero flight riding on
/// it) runs at [AppMotion.duration] instead of the 300 ms Material
/// default, and collapses to zero under reduce-motion.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({required super.builder});

  @override
  Duration get transitionDuration {
    final context = navigator?.context;
    if (context != null && MediaQuery.of(context).disableAnimations) return Duration.zero;
    return AppMotion.duration;
  }
}
