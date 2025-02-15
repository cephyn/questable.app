import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final auth = FirebaseAuth.instance;

  User getCurrentUser() {
    return auth.currentUser!;
  }

  Future<String> getIdToken() async {
    String? token = await auth.currentUser!.getIdToken();
    return token!;
  }

  Future<void> deleteCurrentUser() async {
    await auth.currentUser?.delete();
  }

  Stream<User?> getAuthStateChanges() {
    return auth.authStateChanges();
  }

  Future<void> signOut() async {
    await auth.signOut();
  }
}
