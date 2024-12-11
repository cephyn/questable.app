import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final auth = FirebaseAuth.instance;

  User getCurrentUser() {
    return auth.currentUser!;
  }

  Stream<User?> getAuthStateChanges() {
    return auth.authStateChanges();
  }
}
