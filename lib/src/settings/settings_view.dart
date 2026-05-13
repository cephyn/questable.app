import 'package:flutter/material.dart';

import 'package:quest_cards/src/settings/settings_controller.dart';
import 'package:quest_cards/src/themes/app_theme.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.controller});

  //static const routeName = '/settings';

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        // Glue the SettingsController to the theme selection DropdownButton.
        //
        // When a user selects a theme from the dropdown list, the
        // SettingsController is updated, which rebuilds the MaterialApp.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<ThemeMode>(
              // Read the selected themeMode from the controller
              value: controller.themeMode,
              // Call the updateThemeMode method any time the user selects a theme.
              onChanged: controller.updateThemeMode,
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System Theme'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light Theme'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark Theme'),
                )
              ],
            ),
            const SizedBox(height: 16),
            // Theme Preset Selector
            Text('Theme Preset', style: Theme.of(context).textTheme.labelLarge),
            DropdownButton<ThemePreset>(
              value: controller.themePreset,
              onChanged: (p) {
                if (p != null) controller.updateThemePreset(p);
              },
              items: ThemePreset.values.map((p) {
                final name = p.name;
                final label = name[0].toUpperCase() + name.substring(1);
                return DropdownMenuItem(value: p, child: Text(label));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
