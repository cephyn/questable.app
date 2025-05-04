import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
// import 'package:flutter_localizations/flutter_localizations.dart'; // Commented out localization
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// Admin Views
import 'package:quest_cards/src/admin/game_system_admin_view.dart';
import 'package:quest_cards/src/admin/migration_tools.dart';
import 'package:quest_cards/src/admin/purchase_link_backfill.dart';

// Auth & User
import 'package:quest_cards/src/auth/user_context.dart';
import 'package:quest_cards/src/user/local_user_list.dart';
import 'auth/auth_widgets.dart';

// Quest Card Views
import 'package:quest_cards/src/quest_card/quest_card_edit.dart';
import 'package:quest_cards/src/quest_card/public_quest_card_list_view.dart';
import 'package:quest_cards/src/quest_card/quest_card_list_view.dart';
import 'package:quest_cards/src/quest_card/quest_card_analyze.dart';
import 'package:quest_cards/src/quest_card/quest_card_search.dart';

// Filters
import 'package:quest_cards/src/filters/filter_state.dart';

// Services
import 'services/firebase_auth_service.dart';
import 'services/firestore_service.dart';

// Settings
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';

// App Localization (Commented out)
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';


/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settingsController,
    required this.router, // Add router parameter
  });

  final SettingsController settingsController;
  final GoRouter router; // Add router field

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => FilterProvider()),
            ChangeNotifierProvider(create: (_) => UserContext()),
          ],
          // Use MaterialApp.router
          child: MaterialApp.router(
            restorationScopeId: 'app',
            // Commented out localization delegates
            // localizationsDelegates: const [
            //   AppLocalizations.delegate,
            //   GlobalMaterialLocalizations.delegate,
            //   GlobalWidgetsLocalizations.delegate,
            //   GlobalCupertinoLocalizations.delegate,
            // ],
            // supportedLocales: const [
            //   Locale('en', ''), // English, no country code
            // ],
            // onGenerateTitle: (BuildContext context) =>
            //     AppLocalizations.of(context)!.appTitle,
            title: 'Questable', // Added simple title fallback
            theme: ThemeData(),
            darkTheme: ThemeData.dark(),
            themeMode: settingsController.themeMode,
            // Pass the router configuration
            routerConfig: router,
            // Remove the home property
            // home: HomePage(settingsController: settingsController),
          ),
        );
      },
    );
  }
}


class HomePage extends StatefulWidget {
  final SettingsController settingsController;
  const HomePage({super.key, required this.settingsController});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _selectedIndex = 0;
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: auth.getAuthStateChanges(),
        builder: (context, authSnapshot) {
          final User? currentUser = authSnapshot.data;

          // Loading State
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('Questable')),
              body: const Center(child: CircularProgressIndicator(key: ValueKey('auth_loading'))),
            );
          }

          // Error State
          if (authSnapshot.hasError) {
             return Scaffold(
              appBar: AppBar(title: const Text('Questable')),
              body: Center(child: Text('Authentication Error: ${authSnapshot.error}')),
            );
          }

          // Build AppBar Actions based on auth state
          List<Widget> appBarActions = _buildAppBarActions(currentUser);

          // Build the AppBar
          AppBar appBar = AppBar(
            title: const Text('Questable', style: TextStyle(fontSize: 20)),
            actions: appBarActions,
            automaticallyImplyLeading: false,
          );

          // If user is NOT logged in, show simple Scaffold with PublicQuestCardListView
          if (currentUser == null) {
            // Ensure selected index is 0 for logged-out state
            _selectedIndex = 0;
            return Scaffold(
              key: const ValueKey('logged_out_scaffold'),
              appBar: appBar,
              body: const PublicQuestCardListView(), // Directly show public view
            );
          }
          // If user IS logged in, build the Scaffold with AdaptiveScaffold
          else {
            return buildLoggedInScaffold(currentUser, appBar);
          }
        });
  }

  // Helper to build AppBar actions
  List<Widget> _buildAppBarActions(User? currentUser) {
    return [
      if (currentUser != null) ...[
        IconButton(
          icon: const Icon(Icons.person),
          tooltip: 'Profile (Not Implemented)',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile view not implemented yet.'))
            );
          },
        ),
        IconButton( // Settings Icon
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsView(controller: widget.settingsController),
              ),
            );
          },
        ),
        AuthWidgets.signOutButton(context, auth),
      ] else ...[
        ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Sign In'),
          onPressed: () {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign-in flow not implemented yet.'))
            );
            // TODO: Navigate to sign-in
          },
        )
      ]
    ];
  }

 // Helper function to build destinations for LOGGED-IN users
 List<NavigationDestination> _buildLoggedInDestinations(bool isAdmin) {
    // Assumes currentUser is not null
    return [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Browse', // Index 0
      ),
      // Logged-in only destinations
      const NavigationDestination(
        icon: Icon(Icons.add_circle_outline),
        selectedIcon: Icon(Icons.add_circle),
        label: 'Add Quest', // Index 1
      ),
      const NavigationDestination(
        icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics),
        label: 'Analyze', // Index 2
      ),
      const NavigationDestination(
        icon: Icon(Icons.search_outlined),
        selectedIcon: Icon(Icons.search),
        label: 'Search', // Index 3
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_alt_outlined),
        selectedIcon: Icon(Icons.people_alt),
        label: 'Users', // Index 4
      ),
      // Admin Destinations
      if (isAdmin) ...[
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'Migrate', // Index 5
        ),
        const NavigationDestination(
          icon: Icon(Icons.link_outlined),
          selectedIcon: Icon(Icons.link),
          label: 'Backfill', // Index 6
        ),
         const NavigationDestination(
          icon: Icon(Icons.gamepad_outlined),
          selectedIcon: Icon(Icons.gamepad),
          label: 'Systems', // Index 7
        ),
      ]
    ];
 }


  // Builds the Scaffold containing AdaptiveScaffold for LOGGED-IN users
  Widget buildLoggedInScaffold(User currentUser, AppBar appBar) {
    // Fetch roles for the logged-in user
    final Future<List<String>?> rolesFuture = firestoreService.getUserRoles(currentUser.uid);

    return FutureBuilder<List<String>?>(
        future: rolesFuture,
        builder: (context, roleSnapshot) {
          // Role Loading State
          if (roleSnapshot.connectionState == ConnectionState.waiting) {
             return Scaffold(
               key: const ValueKey('role_loading_scaffold'),
               appBar: appBar, // Use the passed AppBar
               body: const Center(child: CircularProgressIndicator(key: ValueKey('role_loading_indicator'))),
             );
          }
          // Role Error State
          if (roleSnapshot.hasError) {
            print('Error loading user roles: ${roleSnapshot.error}');
             return Scaffold(
               key: const ValueKey('role_error_scaffold'),
               appBar: appBar, // Use the passed AppBar
               body: Center(child: Text('Error loading user data: ${roleSnapshot.error}')),
             );
          }

          // Roles are loaded
          List<String>? roles = roleSnapshot.data;
          bool isAdmin = roles?.contains('admin') ?? false;

          // Build destinations for the logged-in user
          final List<NavigationDestination> destinations = _buildLoggedInDestinations(isAdmin);

          // Ensure selectedIndex is valid
          int effectiveSelectedIndex = _selectedIndex;
          if (effectiveSelectedIndex >= destinations.length) {
            effectiveSelectedIndex = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedIndex = 0;
                });
              }
            });
          }

          // Determine the page widget for the logged-in user
          Widget page;
          switch (effectiveSelectedIndex) {
            case 0: page = QuestCardListView(questCardList: []); break; // Browse
            case 1: page = EditQuestCard(docId: ''); break; // Add Quest
            case 2: page = QuestCardAnalyze(); break; // Analyze
            case 3: page = QuestCardSearch(); break; // Search
            case 4: page = LocalUserList(); break; // Users
            // Admin pages (protected by destination list and this switch)
            case 5: page = isAdmin ? MigrationTools() : QuestCardListView(questCardList: []); break;
            case 6: page = isAdmin ? PurchaseLinkBackfill() : QuestCardListView(questCardList: []); break;
            case 7: page = isAdmin ? GameSystemAdminView() : QuestCardListView(questCardList: []); break;
            default:
              page = QuestCardListView(questCardList: []); // Fallback
          }

          // Build the final Scaffold with AppBar and AdaptiveScaffold body
          return Scaffold(
            key: ValueKey('logged_in_scaffold_${currentUser.uid}'),
            appBar: appBar, // Use the passed AppBar
            body: AdaptiveScaffold(
              selectedIndex: effectiveSelectedIndex,
              onSelectedIndexChange: (int index) {
                 if (index < destinations.length) {
                    setState(() {
                      _selectedIndex = index;
                    });
                 }
              },
              destinations: destinations,
              body: (_) => page,
              smallBody: (_) => page,
              // Standard Breakpoints
               smallBreakpoint: const Breakpoint(endWidth: 700),
               mediumBreakpoint: const Breakpoint(beginWidth: 700, endWidth: 1000),
               largeBreakpoint: const Breakpoint(beginWidth: 1000),
               internalAnimations: true,
            ),
          );
        });
  }
}
