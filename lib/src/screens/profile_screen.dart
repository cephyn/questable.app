import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider; // Hide to avoid conflict
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/providers/auth_provider.dart'
    as app_auth; // Use prefix
import 'package:quest_cards/src/services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // User is now obtained from AuthProvider
  bool _isLoading = false;
  late UserService _userService; // Declare UserService instance

  @override
  void initState() {
    super.initState();
    // Initialize UserService here or in didChangeDependencies if context is needed earlier
    _userService = UserService();
  }

  // Password reset logic
  Future<void> _resetPassword(User? currentUser) async {
    if (currentUser?.email == null) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: currentUser!.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending password reset email: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Account deletion logic with confirmation
  Future<void> _deleteAccount(User? currentUser) async {
    if (currentUser == null) return;

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
              'This action is permanent and cannot be undone. Are you sure you want to delete your account and all associated data?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await currentUser.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully.')),
          );
          // AuthProvider will handle navigation on auth state change
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          // Handle specific errors like 'requires-recent-login'
          String message = 'Error deleting account: $e';
          if (e.code == 'requires-recent-login') {
            message =
                'Please sign out and sign back in again before deleting your account.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(
        context); // Use prefixed AuthProvider
    final User? currentUser = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: currentUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Please log in to view your profile.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go to Home'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // User Info Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User Information',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Email: ${currentUser.email ?? 'Not available'}'),
                        // Add other user details if available (e.g., display name)
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Account Actions Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account Actions',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Column(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.password),
                                    title: const Text('Reset Password'),
                                    subtitle: const Text(
                                        'Send a password reset link to your email'),
                                    onTap: () => _resetPassword(
                                        currentUser), // Pass currentUser
                                  ),
                                  const Divider(),
                                  ListTile(
                                    leading: Icon(Icons.logout,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error),
                                    title: Text('Sign Out',
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error)),
                                    subtitle:
                                        const Text('Sign out of your account'),
                                    onTap: () async {
                                      await authProvider.signOut();
                                      if (mounted &&
                                          !authProvider.isAuthenticated) {
                                        context.go('/');
                                      }
                                    },
                                  ),
                                  const Divider(),
                                  ListTile(
                                      leading: Icon(Icons.delete_forever,
                                          color: Colors.red[700]),
                                      title: Text('Delete Account',
                                          style: TextStyle(
                                              color: Colors.red[700])),
                                      subtitle: const Text(
                                          'Permanently delete your account and data'),
                                      onTap: () => _deleteAccount(
                                          currentUser)), // Pass currentUser
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // My Submissions Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Submissions',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        _buildSubmittedQuestsList(
                            currentUser), // Pass currentUser
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // My Owned Library Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Owned Library',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        _buildOwnedQuestsList(currentUser), // Pass currentUser
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Widget to build the list of submitted quests
  Widget _buildSubmittedQuestsList(User? currentUser) {
    if (currentUser == null) return const Text('Not logged in.');

    return StreamBuilder<QuerySnapshot>(
      stream: _userService.getSubmittedQuestsStream(), // Use UserService
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return SelectableText(
              'Error loading submitted quests: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('You have not submitted any quests yet.');
        }

        final quests = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true, // Important inside a ListView
          physics:
              const NeverScrollableScrollPhysics(), // Disable scrolling within the inner list
          itemCount: quests.length,
          itemBuilder: (context, index) {
            final quest = quests[index];
            final questData =
                quest.data() as Map<String, dynamic>?; // Cast data
            final title = questData?['title'] ?? 'No Title';

            return ListTile(
              title: Text(title),
              // Add subtitle or trailing info if desired
              onTap: () {
                // Navigate to quest details view
                context.go('/quests/${quest.id}');
              },
            );
          },
        );
      },
    );
  }

  // Widget to build the list of owned quests
  Widget _buildOwnedQuestsList(User? currentUser) {
    if (currentUser == null) return const Text('Not logged in.');

    // Future function to get owned quest IDs and then the quest data
    // This is now handled by UserService.getOwnedQuests()
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _userService.getOwnedQuests(), // Use UserService
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return SelectableText(
              'Error loading owned quests: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('You have not marked any quests as owned yet.');
        }
        final quests = snapshot.data!;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: quests.length,
          itemBuilder: (context, index) {
            final quest = quests[index];
            final questData = quest.data() as Map<String, dynamic>?;
            final title = questData?['title'] ?? 'No Title';

            return ListTile(
              title: Text(title),
              onTap: () {
                context.go('/quests/${quest.id}');
              },
            );
          },
        );
      },
    );
  }
}
