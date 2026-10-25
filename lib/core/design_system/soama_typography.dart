import 'package:flutter/material.dart';

/// Centralized typographic scale for Soama.
/// Uses system font styling with refined Apple-like kerning and line-heights.
class SoamaTypography {
  SoamaTypography._();

  static const String fontFamily = 'SF Pro Display';
  static const String fallbackFont = 'Inter';

  // Display
  static const TextStyle displayLarge = TextStyle(
    fontSize: 34.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.18,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.22,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.25,
  );

  // Headlines
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.33,
  );

  // Titles
  static const TextStyle titleLarge = TextStyle(
    fontSize: 17.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.38,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.05,
    height: 1.35,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.15,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.42,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.38,
  );

  // Labels & Captions
  static const TextStyle labelLarge = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.28,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.25,
  );

  // Numeric / Currency callout
  static const TextStyle priceHighlight = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
  );
}
