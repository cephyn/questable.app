import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/auth/auth_gate.dart';
import 'package:quest_cards/src/auth/user_context.dart';
import 'package:quest_cards/src/quest_card/public_quest_card_list_view.dart';
import 'package:quest_cards/src/quest_card/quest_card_edit.dart';
import 'package:quest_cards/src/services/firestore_service.dart';
import 'package:quest_cards/src/settings/settings_controller.dart';

// Forward declaration to avoid circular dependency
// This will be resolved at runtime
typedef HomePageBuilder = Widget Function(SettingsController);

/// RootNavigator is responsible for managing the top-level navigation state
/// of the application, deciding whether to show the public quest list view
/// or the authenticated app interface.
class RootNavigator extends StatefulWidget {
  final HomePageBuilder homePageBuilder;

  const RootNavigator({
    super.key,
    required this.homePageBuilder,
  });

  /// Provides access to the RootNavigator state from anywhere in the app
  static RootNavigatorState? of(BuildContext context) {
    return context.findAncestorStateOfType<RootNavigatorState>();
  }

  @override
  State<RootNavigator> createState() => RootNavigatorState();
}

class RootNavigatorState extends State<RootNavigator>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  String? _pendingAction;
  String? _pendingDocId;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _previousAuthState = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Start with the animation completed
    _animationController.value = 1.0;

    // Add listener to track animation state
    _animationController.addStatusListener(_animationStatusListener);
  }

  void _animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _isAnimating = false;
      });
    } else if (status == AnimationStatus.forward) {
      setState(() {
        _isAnimating = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController.removeStatusListener(_animationStatusListener);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsController = Provider.of<SettingsController>(context);

    // Use ScaffoldMessenger for global snackbars
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Builder(
        builder: (BuildContext scaffoldContext) {
          // Safely access UserContext with error handling
          UserContext? userContext;
          bool isAuthenticated = false;

          try {
            userContext = UserContextProvider.of(context);
            // Check if the user is authenticated with a valid role
            isAuthenticated =
                userContext.isAuthenticated && userContext.hasValidRole;
          } catch (e) {
            // If UserContext is not available, default to unauthenticated
            debugPrint('Error accessing UserContext: $e');
            // Continue with isAuthenticated = false
          }

          // Only animate when auth state actually changes and not already animating
          if (!_isAnimating && isAuthenticated != _previousAuthState) {
            _animationController.reset();
            _animationController.forward();
            _previousAuthState = isAuthenticated;
          }

          // Render the appropriate view based on authentication state
          Widget currentView = isAuthenticated
              ? widget.homePageBuilder(settingsController)
              : PublicQuestCardListView();

          // If there's a pending action and user is now authenticated, handle it
          if (isAuthenticated && _pendingAction != null) {
            // Use post-frame callback to ensure the widget is fully built
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                handlePostAuthAction(scaffoldContext);
              }
            });
          }

          // Apply fade transition
          return FadeTransition(
            opacity: _fadeAnimation,
            child: currentView,
          );
        },
      ),
    );
  }

  /// Prompts the user to login to perform a protected action
  void showLoginPrompt(BuildContext context, String action, {String? docId}) {
    if (!mounted) return;

    setState(() {
      _pendingAction = action;
      _pendingDocId = docId;
    });

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: Text('You need to login to $action.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Only clear the pending action if still mounted
                if (mounted) {
                  setState(() {
                    _pendingAction = null;
                    _pendingDocId = null;
                  });
                }
              },
            ),
            TextButton(
              child: const Text('Login'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                navigateToAuth(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// Navigates to the authentication screen
  void navigateToAuth(BuildContext context) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuthGate(
          onAuthenticated: () {
            // This will be called when authentication is successful
            if (mounted) {
              handlePostAuthAction(context);
            }
          },
        ),
      ),
    );
  }

  /// Handles any pending actions after authentication
  void handlePostAuthAction(BuildContext context) {
    // If no pending action or not mounted, just return
    if (_pendingAction == null || !mounted) return;

    // Store locally to prevent race conditions
    final String action = _pendingAction!;
    final String? docId = _pendingDocId;

    // Clear the pending action and docId first to prevent double handling
    setState(() {
      _pendingAction = null;
      _pendingDocId = null;
    });

    // Handle different types of pending actions
    switch (action) {
      case 'edit':
        if (docId != null) {
          _navigateToEditQuest(context, docId);
        }
        break;
      case 'create':
        _navigateToCreateQuest(context);
        break;
      case 'delete':
        if (docId != null) {
          _handleQuestDeletion(context, docId);
        }
        break;
      case 'admin':
        _showAdminAccessMessage();
        break;
    }
  }

  /// Navigate to edit a quest
  void _navigateToEditQuest(BuildContext context, String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditQuestCard(docId: docId),
      ),
    );
  }

  /// Navigate to create a new quest
  void _navigateToCreateQuest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditQuestCard(docId: ''),
      ),
    );
  }

  /// Handle quest deletion with confirmation dialog
  void _handleQuestDeletion(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
              'Are you sure you want to delete this quest? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await _firestoreService.deleteQuestCard(docId);
                  _showSnackBar('Quest deleted successfully');
                } catch (e) {
                  _showSnackBar('Error deleting quest: $e');
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Show a snackbar message safely
  void _showSnackBar(String message) {
    // Check if the scaffoldMessengerKey has a current state before showing snackbar
    if (_scaffoldMessengerKey.currentState != null) {
      _scaffoldMessengerKey.currentState!
          .showSnackBar(SnackBar(content: Text(message)));
    } else {
      // Fallback to print if scaffold messenger is not available
      debugPrint('Snackbar message (not shown): $message');
    }
  }

  /// Show message for admin access
  void _showAdminAccessMessage() {
    _showSnackBar('You now have access to admin features');
  }
}
