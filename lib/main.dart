import 'dart:convert';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:json_theme/json_theme.dart';
import 'package:go_router/go_router.dart';

import 'package:quest_cards/firebase_options.dart';
import 'package:quest_cards/src/config/config.dart';
import 'package:quest_cards/src/quest_card/quest_card_details_view.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';

// Define the GoRouter configuration
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return HomePage(settingsController: Provider.of<SettingsController>(context));
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'quests/:questId', // Define the route for quest details
          builder: (BuildContext context, GoRouterState state) {
            final questId = state.pathParameters['questId']!;
            return QuestCardDetailsView(docId: questId);
          },
        ),
      ],
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();
  final themeStr =
      await rootBundle.loadString('assets/appainter_theme_green.json');
  final themeJson = jsonDecode(themeStr);
  final theme = ThemeDecoder.decodeThemeData(themeJson)!;

  try {
    // Initialize Firebase with platform-specific options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase Remote Config for secure access to API keys
    await Config.initializeRemoteConfig();
  } catch (e) {
    log('Firebase initialization error: $e');
    // Continue with app initialization even if Firebase fails
  }

  // await FirebaseAppCheck.instance.activate(
  //   webProvider:
  //       ReCaptchaV3Provider('6Ld0AaQqAAAAAP8E4ZBQYrRqbx-XuG96a6ZP_xsT'),
  // );

  //FirebaseUIAuth.configureProviders([
  //  EmailAuthProvider(),
  // ... other providers
  //]);

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settingsController),
      // Add other providers if needed by HomePage or other routes accessed via Provider
    ],
    // Pass the router configuration to MyApp
    child: MyApp(settingsController: settingsController, router: _router),
  ));
}
