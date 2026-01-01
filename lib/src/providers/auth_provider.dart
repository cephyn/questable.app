import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:quest_cards/src/services/firebase_auth_service.dart';

/// Provides authentication state and user information throughout the app.
class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  StreamSubscription<User?>? _authStateSubscription;

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = true; // Start as loading until first auth state is received

  // Track last seen uid to detect sign-in events
  String? _lastSeenUid;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authStateSubscription =
        _authService.getAuthStateChanges().listen((User? user) async {
      // Detect sign-in event (transition from null to non-null or different uid)
      try {
        if (user != null && _lastSeenUid != user.uid) {
          // Record a lightweight auth event (best-effort)
          try {
            // Lazy import of Cloud Functions to avoid dependency during tests
            // Use Firebase Functions callable 'record_auth_event'
            // We do this as a best-effort; failures are ignored
            // Avoid import at top-level to keep dependency minimal
            // ignore: avoid_dynamic_calls
            // Use package import for cloud_functions
            // (Must add firebase_functions to pubspec if not present)
            // Import here to avoid unused import warnings if not used elsewhere
            // NOTE: This call is intentionally fire-and-forget
            // to avoid blocking auth state updates.
            // We avoid awaiting to keep this fast.
            // However, we attempt a non-blocking call using Future.microtask.
            Future.microtask(() async {
              try {
                final callable = FirebaseFunctions.instance.httpsCallable('record_auth_event');
                await callable.call({'event': 'login'});
              } catch (_) {
                // best-effort logging, ignore failures
              }
            });
          } catch (_) {}
        }
      } catch (_) {}

      _currentUser = user;
      _isAuthenticated = user != null;
      _isLoading = false; // No longer loading after first check
      _lastSeenUid = user?.uid;
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
