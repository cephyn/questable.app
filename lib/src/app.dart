import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_donation_buttons/flutter_donation_buttons.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/admin/migration_tools.dart';
import 'package:quest_cards/src/admin/purchase_link_backfill.dart';
import 'package:quest_cards/src/auth/user_context.dart';
import 'package:quest_cards/src/filters/filter_state.dart';
import 'package:quest_cards/src/navigation/root_navigator.dart';
import 'package:quest_cards/src/quest_card/quest_card_edit.dart';
import 'package:quest_cards/src/quest_card/quest_card_details_view.dart'; // Import the details view
import 'package:quest_cards/src/user/local_user_list.dart';

import 'auth/auth_widgets.dart';
import 'quest_card/quest_card_analyze.dart';
import 'quest_card/quest_card_list_view.dart';
import 'quest_card/quest_card_search.dart';
import 'services/firebase_auth_service.dart';
import 'services/firestore_service.dart';
import 'settings/settings_controller.dart';
import 'user/firebase_user_metadata.dart';
import 'user/firebase_user_profile.dart';

class MyApp extends StatelessWidget {
  final ThemeData theme;
  final SettingsController settingsController;
  final String initialRoute;
  final bool darkMode;

  const MyApp({
    super.key,
    required this.theme,
    required this.settingsController,
    this.initialRoute = '/', // Default to root route
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserContext>(
          create: (_) => UserContext(),
        ),
        ChangeNotifierProvider<FilterProvider>(
          create: (_) => FilterProvider(),
        ),
      ],
      child: MaterialApp(
        title: "Questable (Beta)",
        restorationScopeId: 'app',
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
        ],
        // Use RootNavigator with a builder to avoid circular dependency
        home: RootNavigator(
          homePageBuilder: (controller) =>
              HomePage(settingsController: controller),
        ),
        theme: theme,
        // Define routes for navigation
        routes: {
          '/questCardDetails': (context) {
            // Extract arguments and pass to details view
            final args = ModalRoute.of(context)!.settings.arguments
                as Map<String, dynamic>;
            final docId = args['docId'] as String;
            return QuestCardDetailsView(docId: docId);
          },
        },
      ),
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
    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = QuestCardListView(questCardList: []);
        break;
      case 1:
        page = EditQuestCard(
          docId: '',
        );
        break;
      case 2:
        page = QuestCardAnalyze();
        break;
      case 3:
        page = QuestCardSearch();
        break;
      case 4:
        page = LocalUserList();
        break;
      case 5:
        page = MigrationTools(); // Admin-only migration tools
        break;
      case 6:
        page = PurchaseLinkBackfill(); // Admin-only purchase link backfill
        break;
      default:
        page = Placeholder();
    }

    return StreamBuilder<User?>(
        stream: auth.getAuthStateChanges(),
        builder: (context, snapshot) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Questable',
                style: TextStyle(
                  fontSize: 20, // Ensure the title does not get cut off
                ),
              ), // Center the title
              actions: [
                KofiButton(
                    text: 'Support us on Ko-fi',
                    kofiName: "busywyvern",
                    kofiColor: KofiColor.Blue,
                    onDonation: () {
                      //print("On donation"); // Runs after the button has been pressed
                    }),
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<FirebaseUserProfile>(
                        builder: (context) => FirebaseUserProfileWidget(
                          auth: auth,
                          userProfile: FirebaseUserProfile(
                            displayName: auth.getCurrentUser().displayName!,
                            email: auth.getCurrentUser().email!,
                            isEmailVerified:
                                auth.getCurrentUser().emailVerified,
                            isAnonymous: auth.getCurrentUser().isAnonymous,
                            metadata: FirebaseUserMetadata(
                                creationTime: auth
                                    .getCurrentUser()
                                    .metadata
                                    .creationTime!,
                                lastSignInTime: auth
                                    .getCurrentUser()
                                    .metadata
                                    .lastSignInTime!),
                            phoneNumber: auth.getCurrentUser().phoneNumber,
                            photoURL: auth.getCurrentUser().photoURL,
                            providerData: auth.getCurrentUser().providerData,
                            refreshToken: auth.getCurrentUser().refreshToken!,
                            tenantId: auth.getCurrentUser().tenantId,
                            uid: auth.getCurrentUser().uid,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Uncomment if settings button is needed
                // IconButton(
                //   icon: const Icon(Icons.settings),
                //   onPressed: () {
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => SettingsView(
                //           controller: widget.settingsController,
                //         ),
                //       ),
                //     );
                //   },
                // ),
                //const SignOutButton(),
                AuthWidgets.signOutButton(context, auth)
              ],
              automaticallyImplyLeading: false,
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                return adaptiveNav(page);
              },
            ),
          );
        });
  }

  FutureBuilder<List<String>?> adaptiveNav(Widget page) {
    return FutureBuilder<List<String>?>(
        future: firestoreService.getUserRoles(auth.getCurrentUser().uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            List<String>? roles = snapshot.data;
            return AdaptiveScaffold(
              // An option to override the default transition duration.
              //transitionDuration: Duration(milliseconds: _transitionDuration),
              // An option to override the default breakpoints used for small, medium,
              // mediumLarge, large, and extraLarge.
              smallBreakpoint: const Breakpoint(endWidth: 700),
              mediumBreakpoint:
                  const Breakpoint(beginWidth: 700, endWidth: 1000),
              mediumLargeBreakpoint:
                  const Breakpoint(beginWidth: 1000, endWidth: 1200),
              largeBreakpoint:
                  const Breakpoint(beginWidth: 1200, endWidth: 1600),
              extraLargeBreakpoint: const Breakpoint(beginWidth: 1600),
              useDrawer: false,
              selectedIndex: _selectedIndex,
              onSelectedIndexChange: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Quests',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add),
                  label: 'Add Quest',
                ),
                NavigationDestination(
                  icon: Icon(Icons.upload),
                  label: 'Analyze Quest',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: 'Search Quests',
                ),
                if (roles != null && roles.contains('admin'))
                  NavigationDestination(
                    icon: Icon(Icons.people),
                    label: 'List Users',
                  ),
                if (roles != null && roles.contains('admin'))
                  NavigationDestination(
                    icon: Icon(Icons.build),
                    label: 'Migration Tools',
                  ),
                if (roles != null && roles.contains('admin'))
                  NavigationDestination(
                    icon: Icon(Icons.link),
                    label: 'Purchase Link Backfill',
                  ),
              ],
              smallBody: (_) => page,
              body: (_) => page,
              mediumLargeBody: (_) => page,
              largeBody: (_) => page,
              extraLargeBody: (_) => page,
              // Define a default secondaryBody.
              // Override the default secondaryBody during the smallBreakpoint to be
              // empty. Must use AdaptiveScaffold.emptyBuilder to ensure it is properly
              // overridden.
              // smallSecondaryBody: AdaptiveScaffold.emptyBuilder,
              // secondaryBody: (_) => Container(
              //   color: const Color.fromARGB(255, 234, 158, 192),
              // ),
              // mediumLargeSecondaryBody: (_) => Container(
              //   color: const Color.fromARGB(255, 234, 158, 192),
              // ),
              // largeSecondaryBody: (_) => Container(
              //   color: const Color.fromARGB(255, 234, 158, 192),
              // ),
              // extraLargeSecondaryBody: (_) => Container(
              //   color: const Color.fromARGB(255, 234, 158, 192),
              // ),
            );
          } else {
            return Center(child: Text("No roles found"));
          }
        });
  }
}
