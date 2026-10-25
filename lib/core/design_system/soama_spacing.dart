import 'package:flutter/material.dart';

/// Centralized spacing system built on a 4px/8px scale.
class SoamaSpacing {
  SoamaSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double massive = 48.0;
  static const double giant = 64.0;

  // Standard EdgeInsets presets
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(20.0);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 14.0,
  );
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: 14.0,
    vertical: 8.0,
  );
  static const EdgeInsets badgePadding = EdgeInsets.symmetric(
    horizontal: 8.0,
    vertical: 4.0,
  );

  // Standard touch target minimums (accessibility compliant)
  static const double minTouchTarget = 44.0;
  static const double iconSizeSm = 16.0;
  static const double iconSizeMd = 20.0;
  static const double iconSizeLg = 24.0;
  static const double iconSizeXl = 32.0;
}
