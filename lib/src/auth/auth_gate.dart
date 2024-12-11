import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/services/firebase_auth_service.dart';

import '../app.dart';
import '../services/firestore_service.dart';
import '../user/local_user.dart';

class AuthGate extends StatelessWidget {
  AuthGate({super.key});
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();

  @override
  Widget build(BuildContext context) {
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
                  child: Image.asset('assets/images/flutter_logo.png'),
                ),
              );
            },
            subtitleBuilder: (context, action) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: action == AuthAction.signIn
                    ? const Text('Welcome to Quest Cards, please sign in!')
                    : const Text('Welcome to Quest Cars, please sign up!'),
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
                  child: Image.asset('assets/images/flutter_logo.png'),
                ),
              );
            },
          );
        } else {
          //log(snapshot.data!.toString());
          User user = snapshot.data!;
          firestoreService.getLocalUser(user.uid);
        }

        return const HomePage();
      },
    );
  }
}
