import 'package:flutter/material.dart';

/// Centralized corner radii tokens inspired by Apple's squircle ergonomics.
class SoamaRadii {
  SoamaRadii._();

  static const double xs = 6.0;
  static const double sm = 10.0;
  static const double md = 14.0;
  static const double lg = 18.0;
  static const double xl = 22.0;
  static const double xxl = 28.0;
  static const double xxxl = 36.0;
  static const double full = 9999.0;

  // BorderRadius presets
  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius radiusXxxl = BorderRadius.all(Radius.circular(xxxl));
  static const BorderRadius radiusPill = BorderRadius.all(Radius.circular(full));
  static const BorderRadius radiusFull = radiusPill;

  // Top rounded sheets
  static const BorderRadius sheetTopRadius = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
}
