import 'package:flutter/material.dart';

/// Design tokens for clean, modern surface styling without ambient or glowing effects.
class SoamaGlass {
  SoamaGlass._();

  // Blur strengths (Clean UI: zero blur to eliminate ambient haze)
  static const double blurSubtle = 0.0;
  static const double blurStandard = 0.0;
  static const double blurHeavy = 0.0;

  // Specular Border Opacities
  static const double borderOpacityLight = 0.12;
  static const double borderOpacityDark = 0.12;

  // Surface Opacities (Clean, crisp, legible surfaces)
  static const double surfaceAlphaLight = 1.0;
  static const double surfaceAlphaDark = 1.0;

  // Clean UI: No ambient or hazy diffusion shadows
  static const List<BoxShadow> softShadowLight = [];
  static const List<BoxShadow> softShadowDark = [];

  // Clean UI: No elevated ambient halos
  static const List<BoxShadow> elevatedGlassShadowLight = [];
  static const List<BoxShadow> elevatedGlassShadowDark = [];

  // Clean UI: No specular reflection shimmer or ambient light gradients
  static LinearGradient? specularGradient({required bool isDark}) => null;
}
