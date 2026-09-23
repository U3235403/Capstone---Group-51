import 'package:flutter/material.dart';

/// Provisional local tokens based on the inspected green-and-neutral design.
abstract final class AppTheme {
  static const primary = Color(0xFF4D7051);
  static const background = Color(0xFFF8F7F5);
  static const ink = Color(0xFF20211F);
  static const muted = Color(0xFF5B6059);
  static const border = Color(0xFFDADDD6);
  static const controlHeight = 56.0;

  static ThemeData get light => ThemeData(
    fontFamily: 'LocalRoboto',
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      surface: Colors.white,
      onSurface: ink,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: ink,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'LocalRoboto',
        color: ink,
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        fontFamily: 'LocalRoboto',
        fontSize: 18,
        height: 1.4,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'LocalRoboto',
        fontSize: 16,
        height: 1.4,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontFamily: 'LocalRoboto',
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        fontFamily: 'LocalRoboto',
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'LocalRoboto',
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontFamily: 'LocalRoboto', fontSize: 18),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(18),
    ),
  );
}
