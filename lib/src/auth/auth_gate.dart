import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/services/firebase_auth_service.dart';

import '../app.dart';
import '../services/firestore_service.dart';
import '../settings/settings_controller.dart';
import '../util/utils.dart';

class AuthGate extends StatelessWidget {
  /// Callback that is called when authentication is successful
  final VoidCallback? onAuthenticated;

  AuthGate({super.key, this.onAuthenticated});
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();

  @override
  Widget build(BuildContext context) {
    final settingsController = Provider.of<SettingsController>(context);
    Utils.setBrowserTabTitle("Questable");

    return StreamBuilder<User?>(
      stream: auth.getAuthStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(
            providers: [
              EmailAuthProvider(),
              GoogleProvider(
                clientId:
                    "766749273273-cdmn3l0qt31qoqp6uknnboh59aqv1sqn.apps.googleusercontent.com",
              ),
            ],
            headerBuilder: (context, constraints, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/images/Questable.png'),
                ),
              );
            },
            subtitleBuilder: (context, action) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: action == AuthAction.signIn
                    ? const Text(
                        'Welcome to Questable (Beta), please sign in!',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      )
                    : const Text(
                        'Welcome to Questable (Beta), please sign up!',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              );
            },
            footerBuilder: (context, action) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: RichText(
                  text: TextSpan(
                    children: <TextSpan>[
                      TextSpan(
                          text:
                              'By signing in, you agree to our terms and conditions. All information listed in this website is user-generated or AI-generated and may not be accurate. Please use at your own risk. We do not verify the data listed for a Quest\'s content. Please verify the information before using it in your game. If you find the information is incorrect, please correct it. Please do not maliciously alter data. We reserve the right to remove any data we find to be incorrect or malicious. We reserve the right to ban users who maliciously alter data.'),
                      Utils.createHyperlink(
                          'mailto: admin@questable.app', 'Contact us '),
                      TextSpan(text: 'for any questions or concerns.'),
                    ],
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            },
            sideBuilder: (context, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/images/QuestableTx4x4.png'),
                ),
              );
            },
          );
        } else {
          // If onAuthenticated callback is provided, call it and return to previous screen
          if (onAuthenticated != null) {
            // Use a post-frame callback to ensure the UI is ready before navigating
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onAuthenticated!();
              Navigator.of(context).pop(); // Return to the previous screen
            });
            // Show a loading indicator while transitioning
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return FutureBuilder<void>(
            future: firestoreService.storeInitialUserRole(
                auth.getCurrentUser().uid, auth.getCurrentUser().email!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child:
                        CircularProgressIndicator()); // Display a loading indicator
              } else if (snapshot.hasError) {
                return Center(
                    child: Text(
                        'Error: ${snapshot.error}')); // Display error message
              } else {
                return FutureBuilder<List<String>?>(
                  future:
                      firestoreService.getUserRoles(auth.getCurrentUser().uid),
                  builder: (BuildContext context,
                      AsyncSnapshot<List<String>?> rolesSnapshot) {
                    if (rolesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Scaffold(
                          body: Center(child: CircularProgressIndicator()));
                    } else if (rolesSnapshot.hasError) {
                      return Scaffold(
                          body: Center(
                              child: SelectableText(
                                  'Error: ${rolesSnapshot.error}')));
                    } else if (rolesSnapshot.hasData) {
                      List<String>? roles = rolesSnapshot.data;
                      if (roles != null &&
                          (roles.contains('admin') || roles.contains('user'))) {
                        return HomePage(settingsController: settingsController);
                      } else {
                        return Scaffold(
                          body: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 100,
                                      color: Theme.of(context).primaryColor),
                                  const SizedBox(height: 20),
                                  Text(
                                    "Thanks for signing up!",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "An admin will process your account soon.",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  Divider(thickness: 2),
                                  const SizedBox(height: 20),
                                  const SignOutButton(),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    } else {
                      return Scaffold(
                          body: Center(child: Text('No roles found')));
                    }
                  },
                );
              }
            },
          );
        }
      },
    );
  }
}
