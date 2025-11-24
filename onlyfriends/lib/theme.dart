import 'package:flutter/material.dart';

// SideQuest blue palette (approx. like the screenshots)
const Color kNavy = Color(0xFF0B2233); // very dark header accent
const Color kDeepBlue = Color(0xFF0E4A7C);
const Color kBrightBlue = Color(0xFF2E7CF6);
const Color kSky = Color(0xFF8EC9FF);
const Color kPale = Color(0xFFEAF6FF);

ThemeData buildSideQuestTheme() {
  final base = ThemeData(useMaterial3: true);
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: kBrightBlue,
    onPrimary: Colors.white,
    secondary: kDeepBlue,
    onSecondary: Colors.white,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    surface: kPale,
    onSurface: kNavy,
    tertiary: kSky,
    onTertiary: kNavy,
    surfaceContainerHighest: Colors.white,
    surfaceContainerHigh: Colors.white,
    surfaceContainer: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainerLowest: Colors.white,
    outline: kDeepBlue.withOpacity(0.2),
    outlineVariant: kDeepBlue.withOpacity(0.12),
    primaryContainer: kSky,
    onPrimaryContainer: kNavy,
    secondaryContainer: kSky,
    onSecondaryContainer: kNavy,
    surfaceBright: kSky,
    surfaceDim: kPale,
    inversePrimary: kDeepBlue,
    shadow: Colors.black12,
    scrim: Colors.black38,
  );

  return base.copyWith(
    scaffoldBackgroundColor: kPale,
    colorScheme: colorScheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: kPale,
      foregroundColor: kNavy,
      centerTitle: true,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: kDeepBlue.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: kDeepBlue.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kBrightBlue, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kBrightBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrightBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kDeepBlue),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    )
  );
}

ThemeData buildSideQuestDarkTheme() {
  final base = ThemeData(useMaterial3: true);
  const darkBg = Color(0xFF000000);
  const darkSurface = Color(0xFF0A0A0A);
  const darkCard = Color(0xFF111111);
  final colorScheme = const ColorScheme.dark(
    primary: kBrightBlue,
    onPrimary: Colors.white,
    secondary: kSky,
    onSecondary: Colors.black,
    error: Color(0xFFEF5350),
    onError: Colors.white,
    surface: darkSurface,
    onSurface: Colors.white,
  ).copyWith(
    outline: Colors.white.withOpacity(0.12),
    outlineVariant: Colors.white.withOpacity(0.08),
    shadow: Colors.black54,
    scrim: Colors.black87,
  );

  return base.copyWith(
    scaffoldBackgroundColor: darkBg,
    colorScheme: colorScheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kBrightBlue, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kBrightBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrightBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kSky),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
