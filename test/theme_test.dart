import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_cards/src/themes/app_theme.dart';
import 'package:quest_cards/src/settings/settings_controller.dart';
import 'package:quest_cards/src/settings/settings_service.dart';
import 'package:quest_cards/src/settings/settings_view.dart';

void main() {
  test('AppTheme provides Material3 ThemeData', () {
    final light = AppTheme.lightTheme();
    final dark = AppTheme.darkTheme();

    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.colorScheme, isNotNull);
    expect(dark.colorScheme, isNotNull);
  });

  testWidgets('SettingsView shows theme preset selector', (tester) async {
    final controller = SettingsController(SettingsService());
    await controller.loadSettings();

    await tester.pumpWidget(MaterialApp(home: SettingsView(controller: controller)));

    // There should be two DropdownButtons (theme mode and preset)
    expect(find.byType(DropdownButton<ThemeMode>), findsOneWidget);
    expect(find.byType(DropdownButton<ThemePreset>), findsOneWidget);
  });
}
