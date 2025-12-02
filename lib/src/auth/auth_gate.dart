import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:quest_cards/src/services/firebase_auth_service.dart';

import '../app.dart';
import '../services/firestore_service.dart';
import '../settings/settings_controller.dart';
import '../util/utils.dart';

class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();

  @override
  Widget build(BuildContext context) {
    final settingsController = Provider.of<SettingsController>(context);
    Utils.setBrowserTabTitle("Questable");

    return FirebaseUIActions(
      actions: [
        AuthStateChangeAction<SignedIn>((context, state) {
          // User successfully signed in, let build handle navigation
        }),
        AuthStateChangeAction<UserCreated>((context, state) {
          // New user created, let build handle navigation
        }),
      ],
      child: StreamBuilder<User?>(
        stream: auth.getAuthStateChanges(),
        builder: (context, snapshot) {
          // Show loading indicator while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData) {
            return SignInScreen(
              providers: FirebaseUIAuth.providersFor(FirebaseAuth.instance.app),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: <TextSpan>[
                            TextSpan(
                                text:
                                    'By signing in, you agree to our terms and conditions. All information listed in this website is user-generated or AI-generated and may not be accurate. Please use at your own risk.'),
                            Utils.createHyperlink(
                                'mailto: admin@questable.app', ' Contact us '),
                            TextSpan(text: 'for any questions or concerns.'),
                          ],
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Continue with Google'),
                        onPressed: () async {
                          try {
                            // Start Google Sign-In flow
                            final googleUser = await GoogleSignIn.instance.authenticate();
                            // `authenticate` returns a non-null GoogleSignInAccount in v7.x
                            final googleAuth = googleUser.authentication;
                            final credential = fb_auth.GoogleAuthProvider.credential(
                              idToken: googleAuth.idToken,
                            );
                            await fb_auth.FirebaseAuth.instance
                                .signInWithCredential(credential);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Google sign-in failed: $e')),
                            );
                          }
                        },
                      ),
                    ],
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
          }

          // User is authenticated
          final User user = snapshot.data!;
          return FutureBuilder<void>(
            future: firestoreService.storeInitialUserRole(
                user.uid, user.email ?? ''),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              } else if (snapshot.hasError) {
                return Scaffold(
                    body: Center(child: Text('Error: ${snapshot.error}')));
              } else {
                return FutureBuilder<List<String>?>(
                    future:
                      firestoreService.getUserRoles(user.uid),
                  builder: (BuildContext context,
                      AsyncSnapshot<List<String>?> rolesSnapshot) {
                    if (rolesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
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
                        return const Scaffold(
                          body: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 100),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "Thanks for signing up!",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "An admin will process your account soon.",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  const Divider(thickness: 2),
                                  const SizedBox(height: 20),
                                  const SignOutButton(),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    } else {
                      return const Scaffold(
                          body: Center(child: Text('No roles found')));
                    }
                  },
                );
              }
            },
          );
        },
      ),
    );
  }
}
