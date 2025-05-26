import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:quest_cards/firebase_options.dart';
import 'package:quest_cards/src/config/config.dart';
import 'package:quest_cards/src/quest_card/quest_card_details_view.dart';
import 'package:quest_cards/src/screens/profile_screen.dart'; // Import ProfileScreen
import 'package:quest_cards/src/providers/auth_provider.dart'; // Import AuthProvider

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';

// Define the GoRouter configuration
final GoRouter _router = GoRouter(
  redirect: (BuildContext context, GoRouterState state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isAuthenticated = authProvider.isAuthenticated;
    final bool isLoading = authProvider.isLoading; // Get loading state

    // While auth state is loading, don't redirect yet.
    // This prevents a flicker to login screen if already authenticated.
    if (isLoading) {
      return null; // Or return a specific loading route if you have one
    }

    final bool isLoggingIn =
        state.matchedLocation == '/login'; // Assuming you have a /login route

    // If user is not authenticated and not trying to log in, redirect to login.
    // Adjust '/login' if your login route is different.
    // If you don't have a separate login screen and handle login on '/', adjust accordingly.
    if (!isAuthenticated && !isLoggingIn && state.matchedLocation != '/') {
      // Allow access to '/' (home) even if not authenticated.
      // Add other public routes here if needed.
      if (state.matchedLocation == '/profile') {
        // Specifically for /profile
        return '/'; // Redirect to home, or a login page if you have one e.g., '/login'
      }
    }
    return null; // No redirect needed
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return HomePage(
            settingsController: Provider.of<SettingsController>(context));
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'quests/:questId', // Define the route for quest details
          builder: (BuildContext context, GoRouterState state) {
            final questId = state.pathParameters['questId']!;
            return QuestCardDetailsView(docId: questId);
          },
        ),
        GoRoute(
          // Add route for profile screen
          path: 'profile',
          builder: (BuildContext context, GoRouterState state) {
            // Authentication check is now handled by the redirect logic
            return const ProfileScreen();
          },
          routes: const <RouteBase>[], // Ensure profile has no sub-routes that might bypass guard
        ),
        // Potentially add a login route if you don't have one
        // GoRoute(
        //   path: '/login',
        //   builder: (BuildContext context, GoRouterState state) {
        //     return const LoginScreen(); // Create LoginScreen widget
        //   },
        // ),
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

  try {
    // Initialize Firebase with platform-specific options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase Remote Config for secure access to API keys
    // await Config.initializeRemoteConfig(); // Previous commented out line
    await Config.initializeAppConfig(); // Corrected and uncommented
  } catch (e) {
    log('Firebase initialization error: $e');
    // Continue with app initialization even if Firebase fails
  }

  // It's important that AuthProvider is available early for GoRouter redirect logic.
  // So, we create it here before runApp if it's used in GoRouter's redirect.
  final authProvider = AuthProvider(); // Create instance of your AuthProvider

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsController),
        ChangeNotifierProvider.value(
            value: authProvider), // Provide the created AuthProvider instance
      ],
      child: MyApp(settingsController: settingsController, router: _router),
    ),
  );
}
