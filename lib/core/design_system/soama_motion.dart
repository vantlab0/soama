import 'package:flutter/material.dart';

/// Centralized motion tokens for Apple-like spring transitions and subtle physics.
class SoamaMotion {
  SoamaMotion._();

  // Durations
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration snappy = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration deliberate = Duration(milliseconds: 380);
  static const Duration splash = Duration(milliseconds: 600);

  // Curves
  static const Curve easeOutSpring = Cubic(0.18, 0.89, 0.32, 1.28);
  static const Curve smoothOut = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Curve standardEasing = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve linear = Curves.linear;

  /// Returns true if reduced motion is requested by the OS.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Returns an effective duration adjusted for accessibility.
  static Duration responsiveDuration(BuildContext context, Duration original) {
    return isReducedMotion(context) ? Duration.zero : original;
  }
}
