import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/services/firebase_auth_service.dart';
import 'package:quest_cards/src/services/firestore_service.dart';
import 'package:quest_cards/src/user/local_user.dart';

/// Provides user authentication state and role information throughout the app
class UserContext extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? _user;
  List<String>? _roles;
  bool _isLoading = false;

  UserContext() {
    _initializeAuthListener();
  }

  // Public getters
  User? get user => _user;
  List<String> get roles => _roles ?? [];
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => roles.contains('admin');
  bool get isRegularUser => roles.contains('user');
  bool get hasValidRole => isAdmin || isRegularUser;

  // Initialize Firebase Auth listener
  void _initializeAuthListener() {
    _authService.getAuthStateChanges().listen((User? user) {
      _user = user;

      // Reset roles when user changes
      _roles = null;

      // Load roles if user is authenticated
      if (user != null) {
        _loadUserRoles(user.uid);
      }

      notifyListeners();
    });
  }

  // Load user roles from Firestore
  Future<void> _loadUserRoles(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _roles = await _firestoreService.getUserRoles(userId);
    } catch (e) {
      debugPrint('Error loading user roles: $e');
      _roles = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Sign out the current user
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _roles = null;
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // Check if user has a specific role
  bool hasRole(String role) {
    return roles.contains(role);
  }

  // Check if user can edit a quest
  bool canEditQuest(String uploadedBy) {
    // Admins can edit any quest
    if (isAdmin) return true;

    // Regular users can only edit their own quests
    if (isRegularUser && _user != null) {
      return uploadedBy == _user!.uid;
    }

    return false;
  }

  // Check if user can delete a quest
  bool canDeleteQuest(String uploadedBy) {
    // Same rules as editing for now
    return canEditQuest(uploadedBy);
  }
}

/// Provider for UserContext
class UserContextProvider extends InheritedNotifier<UserContext> {
  const UserContextProvider({
    super.key,
    required UserContext userContext,
    required super.child,
  }) : super(notifier: userContext);

  static UserContext of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<UserContextProvider>();
    if (provider == null) {
      throw Exception('UserContextProvider not found in widget tree');
    }
    return provider.notifier!;
  }
}
