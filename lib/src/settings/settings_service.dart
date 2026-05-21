import 'package:flutter/material.dart';
import 'package:quest_cards/src/themes/app_theme.dart';

/// A service that stores and retrieves user settings.
///
/// By default, this class does not persist user settings. If you'd like to
/// persist the user settings locally, use the shared_preferences package. If
/// you'd like to store settings on a web server, use the http package.
class SettingsService {
  /// Loads the User's preferred ThemeMode from local or remote storage.
  Future<ThemeMode> themeMode() async => ThemeMode.system;

  /// Loads the user's preferred theme preset name. Defaults to 'classic'.
  Future<String> themePreset() async => 'classic';

  /// Persists the user's preferred ThemeMode to local or remote storage.
  Future<void> updateThemeMode(ThemeMode theme) async {
    // Use the shared_preferences package to persist settings locally or the
    // http package to persist settings over the network.
  }

  /// Persists the user's preferred [ThemePreset]. Implement persistence as needed.
  Future<void> updateThemePreset(ThemePreset preset) async {
    // Persist locally (shared_preferences) or send to a backend as appropriate.
  }
}
