import 'dart:developer';
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
// firebase_auth import not required in main.dart
import 'package:firebase_ui_auth/firebase_ui_auth.dart' hide AuthProvider, ProfileScreen;
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'src/services/early_error_reporter.dart';

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
  // Install a web-only early error hook that reports via plain HTTP,
  // so we get logs even if Firebase isn't initialized yet.
  EarlyErrorReporter.install();

  WidgetsFlutterBinding.ensureInitialized();

  Future<void> reportFatal(Object error, StackTrace stack) async {
    // Best-effort: never crash due to reporting.
    try {
      await FirebaseFunctions.instance.httpsCallable('report_client_error').call({
        'stage': 'fatal',
        'message': 'Uncaught error during app runtime',
        'runId': 'fatal_${DateTime.now().toUtc().toIso8601String()}',
        'error': error.toString(),
        'stack': stack.toString(),
        'context': {
          'kIsWeb': kIsWeb,
        },
      });
    } catch (e) {
      log('Fatal error reporting failed: $e');
      // Fallback for early-startup / callable failures (web).
      await EarlyErrorReporter.report(
        stage: 'fatal_fallback',
        error: error,
        stackTrace: stack,
        runId: 'fatal_${DateTime.now().toUtc().toIso8601String()}',
        context: {
          'callableError': e.toString(),
        },
      );
    }
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    reportFatal(details.exception, details.stack ?? StackTrace.current);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    reportFatal(error, stack);
    return true; // handled
  };

  await runZonedGuarded(() async {
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

      // Firestore on web uses a streaming transport (WebChannel) that can be
      // blocked by ad blockers / privacy extensions, resulting in
      // net::ERR_BLOCKED_BY_CLIENT. Long-polling often works in those cases.
      //
      // NOTE: Web persistence can throw (especially in Incognito / blocked
      // IndexedDB). Make it best-effort and fall back to persistence disabled.
      if (kIsWeb) {
        const base = Settings(
          persistenceEnabled: false,
          webExperimentalAutoDetectLongPolling: true,
          // NOTE: Do not enable both auto-detect and force long-polling.
          webExperimentalForceLongPolling: false,
        );
        try {
          FirebaseFirestore.instance.settings = base;
        } catch (e) {
          log('Firestore web settings failed, continuing: $e');
        }
      }

      // Configure Firebase UI Auth providers globally (Email only).
      // Google sign-in is handled directly via google_sign_in to avoid
      // the firebase_ui_oauth_google package which blocked upgrades.
      FirebaseUIAuth.configureProviders([
        EmailAuthProvider(),
      ]);

      // Initialize Firebase Remote Config for secure access to API keys
      await Config.initializeAppConfig();
    } catch (e, st) {
      log('Firebase initialization error: $e');
      reportFatal(e, st);
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
  }, (Object error, StackTrace stack) {
    reportFatal(error, stack);
  });
}
