import 'dart:convert';
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
import '../user/local_user.dart';

class AuthGate extends StatelessWidget {
  AuthGate({super.key});
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();

  @override
  Widget build(BuildContext context) {
    final settingsController = Provider.of<SettingsController>(context);
    return StreamBuilder<User?>(
      stream: auth.getAuthStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(
            providers: [
              EmailAuthProvider(),
              GoogleProvider(
                  clientId:
                      "766749273273-cdmn3l0qt31qoqp6uknnboh59aqv1sqn.apps.googleusercontent.com"),
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
                        'Welcome to Questable, please sign in!',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      )
                    : const Text(
                        'Welcome to Questable, please sign up!',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              );
            },
            footerBuilder: (context, action) {
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'By signing in, you agree to our terms and conditions.',
                  style: TextStyle(color: Colors.grey),
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
          FutureBuilder<void>(
            future: firestoreService.storeInitialUserRole(
                auth.getCurrentUser().uid, auth.getCurrentUser().email!),
            builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator(); // Display a loading indicator
              } else if (snapshot.hasError) {
                return Text(
                    'Error: ${snapshot.error}'); // Display error message
              } else {
                return Text(
                    'User role initialized successfully!'); // Display success message
              }
            },
          );
        }

        return FutureBuilder<List<String>?>(
          future: firestoreService.getUserRoles(auth.getCurrentUser().uid),
          builder:
              (BuildContext context, AsyncSnapshot<List<String>?> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData) {
              List<String>? roles = snapshot.data;
              if (roles != null &&
                  (roles.contains('admin') || roles.contains('user'))) {
                return HomePage(settingsController: settingsController);
              } else {
                return Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Thanks for signing up, an admin will process your signup soon.",
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(
                            height:
                                20), // Add space between the text and button
                        const SignOutButton(),
                      ],
                    ),
                  ),
                );
// Or any other widget for non-admin users
              }
            } else {
              return Scaffold(body: Text('No roles found'));
            }
          },
        );
      },
    );
  }
}
