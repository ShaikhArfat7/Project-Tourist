import 'package:flutter/material.dart';

class AppTheme {
  static const orange = Color(0xFFD9622B);
  static const orangeDark = Color(0xFF7C2D12);
  static const orangeTint = Color(0xFFFDEEE3);
  static const textDark = Color(0xFF3A2415);
  static const muted = Color(0xFF8A6B5C);

  static final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: orange,
      primary: orange,
      secondary: orangeDark,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: orangeDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    useMaterial3: true,
  );
}
