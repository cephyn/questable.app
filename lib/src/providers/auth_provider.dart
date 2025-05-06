import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/services/firebase_auth_service.dart';

/// Provides authentication state and user information throughout the app.
class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  StreamSubscription<User?>? _authStateSubscription;

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = true; // Start as loading until first auth state is received

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authStateSubscription =
        _authService.getAuthStateChanges().listen((User? user) {
      _currentUser = user;
      _isAuthenticated = user != null;
      _isLoading = false; // No longer loading after first check
      notifyListeners();
    }, onError: (error) {
      // Handle potential errors listening to auth state
      debugPrint("Error listening to auth state: $error");
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  // Optional: Add methods to trigger sign-in/sign-out if needed centrally
  Future<void> signOut() async {
    await _authService.signOut();
    // Auth state listener will automatically update the state
  }
}
