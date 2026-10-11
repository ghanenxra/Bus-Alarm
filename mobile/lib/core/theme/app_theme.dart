import 'package:flutter/material.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppTokens.background,
      colorScheme: const ColorScheme.dark(
        primary: AppTokens.primary,
        onPrimary: AppTokens.onPrimary,
        surface: AppTokens.surface,
        onSurface: AppTokens.onBackground,
        error: AppTokens.error,
        onError: AppTokens.onError,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTokens.headlineMedium,
        iconTheme: IconThemeData(color: AppTokens.onBackground),
      ),
      cardTheme: CardThemeData(
        color: AppTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          side: const BorderSide(color: AppTokens.surfaceBorder, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          borderSide: const BorderSide(color: AppTokens.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          borderSide: const BorderSide(color: AppTokens.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          borderSide: const BorderSide(color: AppTokens.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          borderSide: const BorderSide(color: AppTokens.error),
        ),
        hintStyle: AppTokens.bodySmall,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.primary,
          foregroundColor: AppTokens.onPrimary,
          minimumSize: const Size.fromHeight(48.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          ),
          textStyle: AppTokens.labelMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.onBackground,
          side: const BorderSide(color: AppTokens.surfaceBorder),
          minimumSize: const Size.fromHeight(48.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          ),
          textStyle: AppTokens.labelMedium,
        ),
      ),
    );
  }
}

