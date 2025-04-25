import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added missing import
import 'package:quest_cards/src/auth/user_context.dart';
import 'package:quest_cards/src/services/firestore_service.dart';
import 'package:provider/provider.dart';

/// A utility page for running database migrations
/// This should only be accessible to admin users
class MigrationTools extends StatefulWidget {
  const MigrationTools({super.key});

  @override
  State<MigrationTools> createState() => _MigrationToolsState();
}

class _MigrationToolsState extends State<MigrationTools> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isRunning = false;
  String _statusMessage = '';
  bool _success = false;

  // New state variables for checking functionality
  bool _isChecking = false;
  String _checkStatusMessage = '';
  int _missingFieldCount = -1;

  @override
  Widget build(BuildContext context) {
    final userContext = Provider.of<UserContext>(context);

    // Only accessible to admins
    if (!userContext.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
        ),
        body: const Center(
          child: Text('You must be an admin to access this page.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Migration Tools'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Database Migration Utilities',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // First card: Check for missing fields
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check for Missing isPublic Fields',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This operation will scan your database and report how many documents are missing '
                      'the isPublic field, which is needed for filtering to work correctly.',
                    ),
                    const SizedBox(height: 16),
                    if (_checkStatusMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: _missingFieldCount == 0
                            ? Colors.green.shade100
                            : _missingFieldCount > 0
                                ? Colors.orange.shade100
                                : Colors.grey.shade100,
                        width: double.infinity,
                        child: Text(_checkStatusMessage),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isChecking ? null : _checkMissingFields,
                      child: _isChecking
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Checking...'),
                              ],
                            )
                          : const Text('Check Missing Fields'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Second card: Run migration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add isPublic Field to Quest Cards',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This migration adds the isPublic field (set to true) to all quest cards that are missing it. '
                      'This is required for the filtering functionality to work properly.',
                    ),
                    const SizedBox(height: 16),
                    if (_statusMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: _success
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        width: double.infinity,
                        child: Text(_statusMessage),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isRunning ? null : _runIsPublicMigration,
                      child: _isRunning
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Running Migration...'),
                              ],
                            )
                          : const Text('Run Migration'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Third card: Test Query
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Filter Query',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will run a simple test query to check if your Firestore indexes are properly '
                      'configured for the isPublic field. If the indexes are not set up correctly, you\'ll '
                      'see an error message with instructions.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _testFilterQuery,
                      child: const Text('Run Test Query'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkMissingFields() async {
    setState(() {
      _isChecking = true;
      _checkStatusMessage = 'Checking for missing fields...';
      _missingFieldCount = -1;
    });

    try {
      final missingCount = await _firestoreService.checkMissingIsPublicField();

      if (mounted) {
        setState(() {
          _isChecking = false;
          if (missingCount == 0) {
            _checkStatusMessage = 'All documents have the isPublic field! ✓';
          } else if (missingCount > 0) {
            _checkStatusMessage =
                'Found $missingCount documents missing the isPublic field. Run the migration to fix.';
          } else {
            _checkStatusMessage = 'Error checking documents. Please try again.';
          }
          _missingFieldCount = missingCount;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _checkStatusMessage = 'Error checking fields: $e';
          _missingFieldCount = -1;
        });
      }
    }
  }

  Future<void> _testFilterQuery() async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Create a test query that should work with your indexes
      final result = await FirebaseFirestore.instance
          .collection('questCards')
          .where('isPublic', isEqualTo: true)
          .where('classification', isEqualTo: 'Adventure')
          .orderBy('title')
          .limit(1)
          .get();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content:
              Text('Query successful! Found ${result.docs.length} documents.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      final errorMessage = e.toString();
      String displayMessage = 'Query failed: $e';
      bool hasIndexLink = false;
      String indexLink = '';

      // Extract the index creation link if it's present in the error
      if (errorMessage.contains('https://console.firebase.google.com/')) {
        try {
          final linkRegex =
              RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
          final match = linkRegex.firstMatch(errorMessage);
          if (match != null) {
            indexLink = match.group(0)!;
            hasIndexLink = true;
            displayMessage =
                'The query requires a composite index that needs to be created.';
          }
        } catch (_) {
          // If regex fails, fall back to the original error message
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayMessage),
              if (hasIndexLink)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Click on the link in the Firebase console to create the required index.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 15),
          action: SnackBarAction(
            label: hasIndexLink ? 'Copy Link' : 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              if (hasIndexLink) {
                // Copy the link to clipboard
                final data = ClipboardData(text: indexLink);
                Clipboard.setData(data);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied to clipboard'),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ),
      );

      // Print the full error with the link to the console for easy access
      if (hasIndexLink) {
        print('Index creation link: $indexLink');
      }
    }
  }

  Future<void> _runIsPublicMigration() async {
    setState(() {
      _isRunning = true;
      _statusMessage = 'Running migration...';
      _success = false;
    });

    try {
      await _firestoreService.migrateQuestCardsAddIsPublic();

      if (mounted) {
        setState(() {
          _isRunning = false;
          _statusMessage = 'Migration completed successfully!';
          _success = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _statusMessage = 'Error during migration: $e';
          _success = false;
        });
      }
    }
  }
}
