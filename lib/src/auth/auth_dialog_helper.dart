import 'package:flutter/material.dart';
import 'package:quest_cards/src/auth/auth_gate.dart';

/// A helper class for showing authentication-related dialogs
/// and managing authentication flows throughout the app.
class AuthDialogHelper {
  /// Shows a login prompt dialog when a user attempts an action that requires authentication
  ///
  /// Parameters:
  /// - [context]: The BuildContext for showing the dialog
  /// - [action]: Description of the action requiring authentication (e.g. "edit quests")
  /// - [onAuthenticated]: Optional callback to execute after successful authentication
  static void showLoginPrompt(
    BuildContext context,
    String action, {
    VoidCallback? onAuthenticated,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: Text('You need to login to $action.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Login'),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToAuth(context, onAuthenticated);
              },
            ),
          ],
        );
      },
    );
  }

  /// Shows a confirmation dialog with login requirement
  ///
  /// Parameters:
  /// - [context]: The BuildContext for showing the dialog
  /// - [title]: The dialog title
  /// - [message]: The dialog message
  /// - [action]: Description of the action requiring authentication
  /// - [onAuthenticated]: Callback to execute after successful authentication
  static void showConfirmationWithAuth(
    BuildContext context,
    String title,
    String message,
    String action, {
    required VoidCallback onAuthenticated,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Continue'),
              onPressed: () {
                Navigator.of(context).pop();
                showLoginPrompt(context, action,
                    onAuthenticated: onAuthenticated);
              },
            ),
          ],
        );
      },
    );
  }

  /// Navigates to the authentication screen
  ///
  /// Parameters:
  /// - [context]: The BuildContext for navigation
  /// - [onAuthenticated]: Optional callback to execute after successful authentication
  static void _navigateToAuth(
      BuildContext context, VoidCallback? onAuthenticated) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuthGate(),
      ),
    );
  }

  /// Direct navigation to the authentication screen from any part of the app
  ///
  /// Parameters:
  /// - [context]: The BuildContext for navigation
  /// - [isSignUp]: Whether to show the sign-up form instead of sign-in
  /// - [onAuthenticated]: Optional callback to execute after successful authentication
  static void navigateToAuthScreen(
    BuildContext context, {
    bool isSignUp = false,
    VoidCallback? onAuthenticated,
  }) {
    _navigateToAuth(context, onAuthenticated);
  }
}
