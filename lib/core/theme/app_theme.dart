import 'package:flutter/material.dart';

class AppTheme {
  // Primary Teal & Emergency Safety Palette
  static const teal = Color(0xFF0D9488);
  static const tealDark = Color(0xFF115E59);
  static const tealTint = Color(0xFFCCFBF1);
  static const surfaceBg = Color(0xFFF8FAFC);
  static const textDark = Color(0xFF0F172A);
  static const muted = Color(0xFF475569);

  // Risk & Emergency Status Colors
  static const lowRiskGreen = Color(0xFF059669);
  static const cautionAmber = Color(0xFFD97706);
  static const highRiskRed = Color(0xFFDC2626);
  static const slateBorder = Color(0xFFE2E8F0);

  // Semantic & theme aliases
  static const primaryTeal = teal;
  static const surfaceLight = surfaceBg;
  static const darkSlate = textDark;
  static const mutedSlate = muted;
  static const accentOrange = cautionAmber;
  static const emergencyRed = highRiskRed;
  static const orange = teal;
  static const orangeDark = tealDark;
  static const orangeTint = tealTint;

  static final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: teal,
      primary: teal,
      secondary: tealDark,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: surfaceBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: tealDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    useMaterial3: true,
  );
}
