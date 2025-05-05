import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthNotifier extends ChangeNotifier {
  User? _user;
  bool _initialized = false;

  AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      _initialized = true; // Mark as initialized once the first state is received
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isInitialized => _initialized; // Expose initialization status
}
