import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/quest_card/quest_card_edit.dart';
import 'package:quest_cards/src/user/local_user_list.dart';
import 'auth/auth_gate.dart';
import 'quest_card/quest_card_analyze.dart';
import 'quest_card/quest_card_list_view.dart';
import 'quest_card/quest_card_search.dart';
import 'services/firebase_auth_service.dart';
import 'services/firestore_service.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';

class MyApp extends StatelessWidget {
  final ThemeData theme;

  const MyApp({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final settingsController = Provider.of<SettingsController>(context);
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          title: "Questable",
          restorationScopeId: 'app',
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
          ],
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,
          theme: theme,
          home: AuthGate(),
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
    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = QuestCardListView();
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
      default:
        page = Placeholder();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Questable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<ProfileScreen>(
                  builder: (context) => ProfileScreen(
                    appBar: AppBar(
                      title: const Text('User Profile'),
                    ),
                    actions: [
                      SignedOutAction((context) {
                        Navigator.of(context).pop();
                      })
                    ],
                    children: [
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.asset('assets/images/QuestableY4x4.png'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsView(
                    controller: widget.settingsController,
                  ),
                ),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              SafeArea(
                child: FutureBuilder<List<String>?>(
                  future:
                      firestoreService.getUserRoles(auth.getCurrentUser().uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      List<String>? roles = snapshot.data;
                      return NavigationRail(
                        extended: constraints.maxWidth >= 600,
                        trailing: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: FutureBuilder<int>(
                                future: firestoreService.getQuestCardsCount(),
                                builder: (BuildContext context,
                                    AsyncSnapshot<int> snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return CircularProgressIndicator();
                                  } else if (snapshot.hasError) {
                                    return Text(
                                      'Error: ${snapshot.error}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    );
                                  } else if (snapshot.hasData) {
                                    int count = snapshot.data!;
                                    return FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          "$count Quests Scribed",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ));
                                  } else {
                                    return Text(
                                      'No data',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            Divider(),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  const SignOutButton(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        destinations: [
                          NavigationRailDestination(
                            icon: Icon(Icons.home),
                            label: Text('Quests'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.add),
                            label: Text('Add Quest'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.upload),
                            label: Text('Analyze Quest'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.search),
                            label: Text('Search Quests'),
                          ),
                          if (roles != null && roles.contains('admin'))
                            NavigationRailDestination(
                              icon: Icon(Icons.people),
                              label: Text('List Users'),
                            ),
                        ],
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (int index) {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                      );
                    } else {
                      return Center(child: Text("No roles found"));
                    }
                  },
                ),
              ),
              Expanded(
                child: page,
              ),
            ],
          );
        },
      ),
    );
  }
}
