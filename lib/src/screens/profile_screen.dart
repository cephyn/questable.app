import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Firestore access
import 'package:go_router/go_router.dart'; // Added for navigation

// TODO: Import specific service files if needed later
// import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance

  // Password reset logic (TODO removed)
  Future<void> _resetPassword() async {
    if (_currentUser?.email == null) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _currentUser!.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending password reset email: \$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Account deletion logic with confirmation (TODO removed)
  Future<void> _deleteAccount() async {
    if (_currentUser == null) return;

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
        await _currentUser.delete(); // Removed unnecessary '!'
        // User deleted successfully. Auth state listener should handle navigation.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully.')),
          );
          // Optionally navigate away explicitly if auth listener doesn't cover it fast enough
          // Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => LoginScreen()), (route) => false);
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          // Handle specific errors like 'requires-recent-login'
          String message = 'Error deleting account: \$e';
          if (e.code == 'requires-recent-login') {
            message =
                'Please sign out and sign back in again before deleting your account.';
            // Re-authentication prompt TODO removed - message is sufficient for now
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: \$e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: _currentUser == null
          ? const Center(
              child: Text(
                  'Not logged in.')) // Should not happen if routed correctly
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
                        Text(
                            'Email: ${_currentUser.email ?? 'Not available'}'), // Removed unnecessary '!'
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
                                    onTap: _resetPassword,
                                  ),
                                  const Divider(),
                                  ListTile(
                                    leading: Icon(Icons.delete_forever,
                                        color: Colors.red[700]),
                                    title: Text('Delete Account',
                                        style:
                                            TextStyle(color: Colors.red[700])),
                                    subtitle: const Text(
                                        'Permanently delete your account and data'),
                                    onTap: _deleteAccount,
                                  ),
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
                        _buildSubmittedQuestsList(), // Use StreamBuilder widget
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
                        _buildOwnedQuestsList(), // Use FutureBuilder widget
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Widget to build the list of submitted quests
  Widget _buildSubmittedQuestsList() {
    if (_currentUser == null) return const Text('Not logged in.');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('questCards')
          .where('uploadedBy',
              isEqualTo: _currentUser.uid) // Removed unnecessary '!'
          .orderBy('title') // Example ordering
          .snapshots(),
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
                context.go('/quests/\${quest.id}');
              },
            );
          },
        );
      },
    );
  }

  // Widget to build the list of owned quests
  Widget _buildOwnedQuestsList() {
    if (_currentUser == null) return const Text('Not logged in.');

    // Future function to get owned quest IDs and then the quest data
    Future<List<DocumentSnapshot>> getOwnedQuests() async {
      // 1. Get owned quest IDs
      final ownedRefs = await _firestore
          .collection('users')
          .doc(_currentUser.uid) // Removed unnecessary '!'
          .collection('ownedQuests')
          .get();

      final ownedIds = ownedRefs.docs.map((doc) => doc.id).toList();

      if (ownedIds.isEmpty) {
        return [];
      }

      // 2. Get quest documents based on IDs
      // Firestore 'whereIn' query limit is 30. Handle potential batching for > 30 owned quests.
      List<DocumentSnapshot> ownedQuests = [];
      for (var i = 0; i < ownedIds.length; i += 30) {
        final sublist = ownedIds.sublist(
            i, i + 30 > ownedIds.length ? ownedIds.length : i + 30);
        final questSnapshots = await _firestore
            .collection('questCards')
            .where(FieldPath.documentId, whereIn: sublist)
            .get();
        ownedQuests.addAll(questSnapshots.docs);
      }

      // Optional: Sort owned quests if needed, e.g., by title
      ownedQuests.sort((a, b) {
        final titleA = (a.data() as Map<String, dynamic>?)?['title'] ?? '';
        final titleB = (b.data() as Map<String, dynamic>?)?['title'] ?? '';
        return titleA.compareTo(titleB);
      });

      return ownedQuests;
    }

    return FutureBuilder<List<DocumentSnapshot>>(
      future: getOwnedQuests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return SelectableText(
              'Error loading owned quests: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('You do not own any quests yet.');
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
