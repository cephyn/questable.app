import 'package:flutter/material.dart';

/// Centralized Material 3 theme definitions and presets for the app.
enum ThemePreset { classic, forest, retro }

class AppTheme {
  // Maps presets to seed colors. Updated to use Questable brand tones
  // (teals / aqua with supporting green/coral accents) matching the
  // provided design image used in the app branding.
  static const Map<ThemePreset, Color> _presetSeeds = {
    // Primary brand teal used across the UI (CTAs, icons, accents)
    ThemePreset.classic: Color(0xFF138F8A), // Teal / aqua (brand)
    // A greener option for "forest" preset
    ThemePreset.forest: Color(0xFF2E8B57), // Sea-green
    // A warm accent preset for retro / alternate theme
    ThemePreset.retro: Color(0xFFFF8364), // Coral accent
  };

  // Named brand colors (handy for explicit usage elsewhere in the UI)
  static const Map<String, Color> brandColors = {
    'primary': Color(0xFF138F8A), // main teal
    'primaryLight': Color(0xFF3EC1B4),
    'primaryDark': Color(0xFF0B6F6B),
    'accent': Color(0xFF0F8F8A),
    'muted': Color(0xFFAEEDE4),
  };

  static ThemeData lightTheme({String presetName = 'classic'}) {
    final preset = ThemePreset.values.firstWhere(
      (p) => p.name == presetName,
      orElse: () => ThemePreset.classic,
    );
    final seed = _presetSeeds[preset] ?? _presetSeeds[ThemePreset.classic]!;
    final colorScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // Keep legacy compatibility (some widgets still use primaryColor)
      primaryColor: colorScheme.primary,
      // Reasonable defaults for typography + elevated buttons
      textTheme:
          Typography.material2021(platform: TargetPlatform.android).black,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant,
      ),
    );
  }

  static ThemeData darkTheme({String presetName = 'classic'}) {
    final preset = ThemePreset.values.firstWhere(
      (p) => p.name == presetName,
      orElse: () => ThemePreset.classic,
    );
    final seed = _presetSeeds[preset] ?? _presetSeeds[ThemePreset.classic]!;
    final colorScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: colorScheme.primary,
      textTheme:
          Typography.material2021(platform: TargetPlatform.android).white,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant,
      ),
    );
  }
}
