import 'package:flutter/material.dart';

// Brand palette inspired by the provided logo: navy/blue/gold
class BrandPalette {
  static const Color navy = Color(0xFF0F2A5B);
  static const Color blue = Color(0xFF1E4DAC);
  static const Color gold = Color(0xFFF2C200);
  static const Color onPrimary = Colors.white;
}

ThemeData buildLightTheme() {
  const primary = BrandPalette.blue;
  const secondary = BrandPalette.gold;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
    primary: primary,
    onPrimary: BrandPalette.onPrimary,
    secondary: secondary,
  );
  return ThemeData(
    colorScheme: colorScheme,
    brightness: Brightness.light,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    scaffoldBackgroundColor: const Color(0xFFF7F8FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: BrandPalette.onPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: BrandPalette.onPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: BrandPalette.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: primary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: secondary,
      foregroundColor: Colors.black,
    ),
    chipTheme: const ChipThemeData(
      selectedColor: secondary,
      backgroundColor: Color(0xFFEFF3FB),
      labelStyle: TextStyle(color: Colors.black87),
      secondaryLabelStyle: TextStyle(color: Colors.black87),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(
      thickness: 1,
      color: Color(0xFFE6EAF2),
    ),
  );
}

ThemeData buildDarkTheme() {
  const primary = BrandPalette.navy;
  const secondary = BrandPalette.gold;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: BrandPalette.onPrimary,
    secondary: secondary,
  );
  return ThemeData(
    colorScheme: colorScheme,
    brightness: Brightness.dark,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    scaffoldBackgroundColor: const Color(0xFF121418),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: BrandPalette.onPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: BrandPalette.onPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: BrandPalette.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: secondary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: secondary,
      foregroundColor: Colors.black,
    ),
    chipTheme: ChipThemeData(
      selectedColor: secondary,
      backgroundColor: Colors.white.withOpacity(0.08),
      labelStyle: const TextStyle(color: Colors.white),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1B1F26),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(
      thickness: 1,
      color: Color(0xFF2A2F38),
    ),
  );
}
