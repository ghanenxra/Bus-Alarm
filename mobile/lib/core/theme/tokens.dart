import 'package:flutter/material.dart';

class AppTokens {
  // Brand & Semantic Colors
  static const Color primary = Color(0xFF0F62FE); // Precision blue
  static const Color onPrimary = Color(0xFFFFFFFF);
  
  static const Color surface = Color(0xFF161616);
  static const Color surfaceSubtle = Color(0xFF262626);
  static const Color surfaceBorder = Color(0xFF393939);
  
  static const Color background = Color(0xFF121212);
  static const Color onBackground = Color(0xFFF4F4F4);
  static const Color onBackgroundSubtle = Color(0xFF8D8D8D);

  static const Color success = Color(0xFF24A148);
  static const Color warning = Color(0xFFF1C21B);
  static const Color error = Color(0xFFDA1E28);
  static const Color onError = Color(0xFFFFFFFF);

  // Spacing Scale
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // Radii
  static const double radiusSmall = 6.0;
  static const double radiusMedium = 10.0;
  static const double radiusLarge = 16.0;

  // Typography Scale (Display is >2.5x body)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 34.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: onBackground,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    color: onBackground,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    color: onBackground,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: onBackground,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    color: onBackgroundSubtle,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );
}
