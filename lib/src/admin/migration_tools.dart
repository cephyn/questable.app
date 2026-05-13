import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added missing import
import 'package:quest_cards/src/auth/user_context.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/admin/search_backfill_dashboard.dart';

/// A utility page for running database migrations
/// This should only be accessible to admin users
class MigrationTools extends StatefulWidget {
  const MigrationTools({super.key});

  @override
  State<MigrationTools> createState() => _MigrationToolsState();
}

class _MigrationToolsState extends State<MigrationTools> {
  bool _isRunning = false;
  String _statusMessage = '';
  bool _success = false;

  // New state variables for checking functionality
  bool _isChecking = false;
  String _checkStatusMessage = '';
  int _missingFieldCount = -1;

  // New state variables for populating gameSystem_lowercase
  bool _isPopulatingLowercase = false;
  String _populateLowercaseStatus = '';
  bool _populateLowercaseSuccess = false;
  int _populatedLowercaseCount = 0;
  int _processedLowercaseCount = 0;

  // New state variables for backfilling productTitle
  bool _isBackfillingProductTitle = false;
  String _backfillProductTitleStatus = '';
  bool _backfillProductTitleSuccess = false;
  int _backfilledProductTitleCount = 0;
  int _processedProductTitleCount = 0;

  // New state variables for backfilling search index
  bool _isBackfillingSearchIndex = false;
  String _backfillSearchStatus = '';
  bool _backfillSearchSuccess = false;
  int _backfillSearchProcessed = 0;

  // State variables for batch update game system
  bool _isBatchUpdatingGameSystem = false;
  String _batchGameSystemStatus = '';
  bool _batchGameSystemSuccess = false;
  int _batchGameSystemProcessed = 0;
  int _batchGameSystemUpdated = 0;
  final TextEditingController _batchQuestIdController = TextEditingController();
  final TextEditingController _batchGameSystemController =
      TextEditingController();

  // State for uploader email backfill
  bool _isUploaderBackfillRunning = false;
  String _uploaderBackfillStatus = '';

  @override
  Widget build(BuildContext context) {
    final userContext = Provider.of<UserContext>(context);

    // Only accessible to admins
    if (!userContext.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('You must be an admin to access this page.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Database Migration Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          // Changed Column to ListView
          children: [
            const Text(
              'Database Migration Utilities',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // First card: Check for missing isPublic fields
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check for Missing isPublic Fields',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
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
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : _missingFieldCount > 0
                            ? Theme.of(context).colorScheme.tertiaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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

            // Second card: Run isPublic migration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add isPublic Field to Quest Cards',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
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
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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

            // Third card: Test Filter Query
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Filter Query',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
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

            const SizedBox(height: 20), // Add space before the new card
            // Fourth card: Populate gameSystem_lowercase
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Populate gameSystem_lowercase Field',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This tool scans all quest cards and adds/updates the `gameSystem_lowercase` field, '
                      'which is required for case-insensitive game system searching and filtering. '
                      'It only updates documents where the field is missing or incorrect. Safe to re-run.',
                    ),
                    const SizedBox(height: 16),
                    if (_populateLowercaseStatus.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: _populateLowercaseSuccess
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : _isPopulatingLowercase
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                        width: double.infinity,
                        child: Text(_populateLowercaseStatus),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isPopulatingLowercase
                          ? null
                          : _runPopulateLowercaseGameSystem,
                      child: _isPopulatingLowercase
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Populating...'),
                              ],
                            )
                          : const Text('Populate Lowercase Field'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20), // Add some padding at the bottom
            // Fifth card: Backfill productTitle from title
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backfill Missing Product Titles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This tool scans quest cards and populates the `productTitle` field '
                      'with the value from the `title` field if `productTitle` is missing or blank. '
                      'Safe to re-run.',
                    ),
                    const SizedBox(height: 16),
                    if (_backfillProductTitleStatus.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: _backfillProductTitleSuccess
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : _isBackfillingProductTitle
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                        width: double.infinity,
                        child: Text(_backfillProductTitleStatus),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isBackfillingProductTitle
                          ? null
                          : _runBackfillProductTitleMigration,
                      child: _isBackfillingProductTitle
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Backfilling...'),
                              ],
                            )
                          : const Text('Backfill Product Titles'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20), // Add some padding at the bottom
            // Seventh card: Batch Update Game System
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Batch Update Game System',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Update the game system for multiple quests at once. '
                      'Provide a comma-separated list of quest IDs and the new game system name. '
                      'Both `gameSystem` and `standardizedGameSystem` can be updated simultaneously.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _batchQuestIdController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Quest IDs (comma-separated)',
                        hintText: 'e.g., questId1,questId2,questId3',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _batchGameSystemController,
                      decoration: const InputDecoration(
                        labelText: 'New Game System',
                        hintText: 'e.g., Dungeons & Dragons 5e',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_batchGameSystemStatus.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: _batchGameSystemSuccess
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : _isBatchUpdatingGameSystem
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                        width: double.infinity,
                        child: Text(_batchGameSystemStatus),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isBatchUpdatingGameSystem
                          ? null
                          : _runBatchUpdateGameSystem,
                      child: _isBatchUpdatingGameSystem
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Updating...'),
                              ],
                            )
                          : const Text('Batch Update Game System'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20), // Add some padding at the bottom
            // Sixth card: Backfill Search Index
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backfill Search Index',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Populate/refresh the `questSearchIndex` documents for all existing QuestCards by calling the backfill function.',
                    ),
                    const SizedBox(height: 16),
                    if (_backfillSearchStatus.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: _backfillSearchSuccess
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : _isBackfillingSearchIndex
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_backfillSearchStatus),
                            if (_backfillSearchProcessed > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  'Processed: $_backfillSearchProcessed',
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isBackfillingSearchIndex
                              ? null
                              : () async {
                                  await _runBackfillSearchIndex();
                                },
                          child: _isBackfillingSearchIndex
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Running Backfill...'),
                                  ],
                                )
                              : const Text('Run Search Backfill'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _isBackfillingSearchIndex
                              ? null
                              : _checkSearchIndexStatus,
                          child: const Text('Check Status'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SearchBackfillDashboard(),
                              ),
                            );
                          },
                          child: const Text('View Dashboard'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // NEW: Backfill uploader emails (one-off)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Backfill Uploader Emails',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Populate missing `uploaderEmail` on existing QuestCards from the `uploadedBy` user id. Safe to run; will only update missing fields.',
                            ),
                            const SizedBox(height: 12),
                            if (_uploaderBackfillStatus.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(8),
                                color: _isUploaderBackfillRunning
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.secondaryContainer,
                                width: double.infinity,
                                child: Text(_uploaderBackfillStatus),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: _isUploaderBackfillRunning
                                      ? null
                                      : _confirmAndRunUploaderBackfill,
                                  child: _isUploaderBackfillRunning
                                      ? const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text('Running...'),
                                          ],
                                        )
                                      : const Text('Run Backfill'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: _isUploaderBackfillRunning
                                      ? null
                                      : _checkUploaderBackfillStatus,
                                  child: const Text('Check Status'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
      _checkStatusMessage =
          'Checking for missing fields... Fetching documents.';
      _missingFieldCount = 0; // Initialize count to 0
    });

    final firestore = FirebaseFirestore.instance;
    final questCardsRef = firestore.collection('questCards');
    const batchSize = 500; // Process in batches
    int processedCount = 0;
    int missingCount = 0;
    DocumentSnapshot? lastDoc;

    try {
      while (true) {
        Query query = questCardsRef
            .orderBy(FieldPath.documentId)
            .limit(batchSize);
        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        if (!mounted) return; // Check if widget is still mounted
        setState(() {
          _checkStatusMessage =
              'Fetching batch (processed: $processedCount)...';
        });

        final snapshot = await query.get();

        if (snapshot.docs.isEmpty) {
          log('No more documents found for checking.');
          break; // Exit loop
        }

        lastDoc = snapshot.docs.last;
        processedCount += snapshot.docs.length;

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          // Check if the field exists and is not null
          if (data == null || data['isPublic'] == null) {
            missingCount++;
          }
        }

        if (!mounted) return;
        setState(() {
          _checkStatusMessage =
              'Processing... (Checked: $processedCount, Missing: $missingCount)';
        });
      }

      // Final update after loop finishes
      if (mounted) {
        setState(() {
          _isChecking = false;
          if (missingCount == 0) {
            _checkStatusMessage =
                'Check complete! All $processedCount documents have the isPublic field! ✓';
          } else {
            _checkStatusMessage =
                'Check complete! Found $missingCount documents missing the isPublic field out of $processedCount checked. Run the migration to fix.';
          }
          _missingFieldCount = missingCount;
        });
      }
    } catch (e, s) {
      log('Error checking missing isPublic fields: $e', stackTrace: s);
      if (mounted) {
        setState(() {
          _isChecking = false;
          _checkStatusMessage = 'Error checking fields: $e';
          _missingFieldCount = -1; // Indicate error
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
          content: Text(
            'Query successful! Found ${result.docs.length} documents.',
          ),
          backgroundColor: Theme.of(context).colorScheme.secondary,
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
          final linkRegex = RegExp(
            r'https://console\.firebase\.google\.com/[^\s]+',
          );
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
              if (!hasIndexLink)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Additionally, you can run the "Backfill Uploader Emails" migration from this page to normalize uploader data.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 15),
          action: SnackBarAction(
            label: hasIndexLink ? 'Copy Link' : 'Dismiss',
            textColor: Theme.of(context).colorScheme.onError,
            onPressed: () {
              if (hasIndexLink) {
                // Copy the link to clipboard
                final data = ClipboardData(text: indexLink);
                Clipboard.setData(data);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Link copied to clipboard'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ),
      );

      // Print the full error with the link to the console for easy access
      if (hasIndexLink) {
        log('Index creation link: $indexLink');
      }
    }
  }

  // Uploader email backfill helpers
  Future<void> _confirmAndRunUploaderBackfill() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Run Backfill?'),
          content: const Text(
            'This will scan all QuestCards and populate missing uploaderEmail fields from uploadedBy user ids. This may update many documents. Proceed?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Run'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _runUploaderBackfill();
    }
  }

  Future<void> _runUploaderBackfill() async {
    setState(() {
      _isUploaderBackfillRunning = true;
      _uploaderBackfillStatus = 'Running uploader email backfill...';
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'backfill_uploader_emails',
      );
      final resp = await callable.call(<String, dynamic>{});
      final data = Map<String, dynamic>.from(resp.data ?? {});
      final processed = data['processed'] as int? ?? 0;
      final updated = data['updated'] as int? ?? 0;

      setState(() {
        _uploaderBackfillStatus =
            'Backfill complete: processed $processed, updated $updated';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backfill complete: processed $processed, updated $updated',
          ),
        ),
      );
    } catch (e) {
      log('Backfill failed: $e');
      setState(() {
        _uploaderBackfillStatus = 'Backfill failed: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backfill failed: $e')));
    } finally {
      setState(() {
        _isUploaderBackfillRunning = false;
      });
    }
  }

  Future<void> _checkUploaderBackfillStatus() async {
    // For now, we don't have a persistent status; just a placeholder that confirms function exists
    setState(() {
      _uploaderBackfillStatus = 'Backfill function is available. Run to start.';
    });
  }

  Future<void> _runIsPublicMigration() async {
    setState(() {
      _isRunning = true;
      _statusMessage = 'Starting migration... Fetching first batch.';
      _success = false;
    });

    final firestore = FirebaseFirestore.instance;
    final questCardsRef = firestore.collection('questCards');
    const batchSize = 400; // Firestore batch limit is 500 operations
    int batchCounter = 0;
    int updatedCount = 0;
    int processedCount = 0;
    WriteBatch batch = firestore.batch();
    DocumentSnapshot? lastDoc;

    try {
      while (true) {
        // Query for the next batch
        Query query = questCardsRef
            .orderBy(FieldPath.documentId)
            .limit(batchSize);
        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        if (!mounted) return; // Check if widget is still mounted
        setState(() {
          _statusMessage =
              'Fetching next batch (processed: $processedCount, updated: $updatedCount)...';
        });

        final snapshot = await query.get();

        if (snapshot.docs.isEmpty) {
          log('No more documents found for migration.');
          break; // Exit loop
        }

        lastDoc = snapshot.docs.last;
        processedCount += snapshot.docs.length;

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;

          // Check if 'isPublic' field is missing (or null)
          if (data == null || data['isPublic'] == null) {
            batch.update(doc.reference, {'isPublic': true});
            batchCounter++;
            updatedCount++;

            if (batchCounter >= batchSize) {
              if (!mounted) return;
              setState(() {
                _statusMessage =
                    'Committing batch (Processed: $processedCount, Updated: $updatedCount)...';
              });
              log('Committing isPublic migration batch...');
              await batch.commit();
              log('Batch committed.');
              batch = firestore.batch(); // Start new batch
              batchCounter = 0;
              await Future.delayed(
                const Duration(milliseconds: 50),
              ); // Small delay
            }
          }
        }
        // Update status after processing a batch
        if (!mounted) return;
        setState(() {
          _statusMessage =
              'Processing... (Checked: $processedCount, Updated: $updatedCount)';
        });
      }

      // Commit final batch
      if (batchCounter > 0) {
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Committing final batch...';
        });
        log(
          'Committing final isPublic migration batch ($batchCounter operations)...',
        );
        await batch.commit();
        log('Final batch committed.');
      }

      if (mounted) {
        setState(() {
          _isRunning = false;
          _statusMessage =
              'Migration complete! Processed: $processedCount, Updated: $updatedCount';
          _success = true;
        });
      }
    } catch (e, s) {
      log('Error during isPublic migration: $e', stackTrace: s);
      if (mounted) {
        setState(() {
          _isRunning = false;
          _statusMessage =
              'Error during migration: $e. Processed: $processedCount, Updated: $updatedCount';
          _success = false;
        });
      }
      // Optionally try to commit the current batch on error
    }
  }

  /// Runs the process to populate the gameSystem_lowercase field
  Future<void> _runPopulateLowercaseGameSystem() async {
    setState(() {
      _isPopulatingLowercase = true;
      _populateLowercaseStatus = 'Starting population... Fetching first batch.';
      _populateLowercaseSuccess = false;
      _populatedLowercaseCount = 0;
      _processedLowercaseCount = 0;
    });

    final firestore = FirebaseFirestore.instance;
    final questCardsRef = firestore.collection('questCards');
    const batchSize = 400; // Firestore batch limit is 500 operations
    int batchCounter = 0;
    WriteBatch batch = firestore.batch();
    DocumentSnapshot? lastDoc;

    try {
      while (true) {
        // Query for the next batch
        Query query = questCardsRef
            .orderBy(FieldPath.documentId)
            .limit(batchSize);
        if (lastDoc != null) {
          // No need for '!' as lastDoc is checked for null
          query = query.startAfterDocument(lastDoc);
        }

        if (!mounted) return; // Check if widget is still mounted
        setState(() {
          _populateLowercaseStatus =
              'Fetching next batch (processed: $_processedLowercaseCount)...';
        });

        final snapshot = await query.get();

        if (snapshot.docs.isEmpty) {
          log('No more documents found.');
          break; // Exit loop
        }

        lastDoc = snapshot.docs.last;
        final currentBatchSize = snapshot.docs.length;
        log(
          'Processing ${currentBatchSize} documents (up to ${lastDoc.id})...',
        );

        for (final doc in snapshot.docs) {
          _processedLowercaseCount++;
          final data = doc.data() as Map<String, dynamic>?;
          String? gameSystem;
          String? existingLowercase;

          if (data != null) {
            if (data.containsKey('gameSystem') &&
                data['gameSystem'] is String) {
              gameSystem = data['gameSystem'] as String;
            }
            if (data.containsKey('gameSystem_lowercase')) {
              existingLowercase = data['gameSystem_lowercase'] as String?;
            }
          }

          if (gameSystem != null && gameSystem.isNotEmpty) {
            final lowercaseGameSystem = gameSystem.toLowerCase();

            if (existingLowercase == null ||
                existingLowercase != lowercaseGameSystem) {
              batch.update(doc.reference, {
                'gameSystem_lowercase': lowercaseGameSystem,
              });
              batchCounter++;
              _populatedLowercaseCount++;

              if (batchCounter >= batchSize) {
                if (!mounted) return;
                setState(() {
                  _populateLowercaseStatus =
                      'Committing batch (Processed: $_processedLowercaseCount, Updated: $_populatedLowercaseCount)...';
                });
                log('Committing batch...');
                await batch.commit();
                log('Batch committed.');
                batch = firestore.batch(); // Start new batch
                batchCounter = 0;
                await Future.delayed(
                  const Duration(milliseconds: 50),
                ); // Small delay
              }
            }
          }
          // Update status periodically within a batch
          if (_processedLowercaseCount % 100 == 0 && mounted) {
            setState(() {
              _populateLowercaseStatus =
                  'Processing... (Processed: $_processedLowercaseCount, Updated: $_populatedLowercaseCount)';
            });
          }
        }
        if (!mounted) return;
        setState(() {
          _populateLowercaseStatus =
              'Finished processing batch. (Total Processed: $_processedLowercaseCount, Total Updated: $_populatedLowercaseCount)';
        });
      }

      // Commit final batch
      if (batchCounter > 0) {
        if (!mounted) return;
        setState(() {
          _populateLowercaseStatus = 'Committing final batch...';
        });
        log('Committing final batch ($batchCounter operations)...');
        await batch.commit();
        log('Final batch committed.');
      }

      if (mounted) {
        setState(() {
          _isPopulatingLowercase = false;
          _populateLowercaseStatus =
              'Population complete! Processed: $_processedLowercaseCount, Updated/Verified: $_populatedLowercaseCount';
          _populateLowercaseSuccess = true;
        });
      }
    } catch (e, s) {
      log('Error during gameSystem_lowercase population: $e', stackTrace: s);
      if (mounted) {
        setState(() {
          _isPopulatingLowercase = false;
          _populateLowercaseStatus =
              'Error during population: $e. Processed: $_processedLowercaseCount, Updated: $_populatedLowercaseCount';
          _populateLowercaseSuccess = false;
        });
      }
      // Optionally try to commit the current batch on error
    }
  }

  /// Runs the process to backfill productTitle from title if productTitle is blank or missing
  Future<void> _runBackfillProductTitleMigration() async {
    setState(() {
      _isBackfillingProductTitle = true;
      _backfillProductTitleStatus =
          'Starting product title backfill... Fetching first batch.';
      _backfillProductTitleSuccess = false;
      _backfilledProductTitleCount = 0;
      _processedProductTitleCount = 0;
    });

    final firestore = FirebaseFirestore.instance;
    final questCardsRef = firestore.collection('questCards');
    const batchSize = 400; // Firestore batch limit is 500 operations
    int batchCounter = 0;
    WriteBatch batch = firestore.batch();
    DocumentSnapshot? lastDoc;

    try {
      while (true) {
        Query query = questCardsRef
            .orderBy(FieldPath.documentId)
            .limit(batchSize);
        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        if (!mounted) return;
        setState(() {
          _backfillProductTitleStatus =
              'Fetching next batch (processed: $_processedProductTitleCount)...';
        });

        final snapshot = await query.get();

        if (snapshot.docs.isEmpty) {
          log('No more documents found for product title backfill.');
          break;
        }

        lastDoc = snapshot.docs.last;

        for (final doc in snapshot.docs) {
          _processedProductTitleCount++;
          final data = doc.data() as Map<String, dynamic>?;

          String? title;
          String? productTitle;

          if (data != null) {
            if (data.containsKey('title') && data['title'] is String) {
              title = data['title'] as String;
            }
            if (data.containsKey('productTitle')) {
              productTitle = data['productTitle'] as String?;
            }
          }

          // Check if productTitle is null, empty, or just whitespace
          bool productTitleIsBlank =
              productTitle == null || productTitle.trim().isEmpty;

          if (productTitleIsBlank && title != null && title.trim().isNotEmpty) {
            batch.update(doc.reference, {'productTitle': title.trim()});
            batchCounter++;
            _backfilledProductTitleCount++;

            if (batchCounter >= batchSize) {
              if (!mounted) return;
              setState(() {
                _backfillProductTitleStatus =
                    'Committing batch (Processed: $_processedProductTitleCount, Updated: $_backfilledProductTitleCount)...';
              });
              log('Committing product title backfill batch...');
              await batch.commit();
              log('Product title backfill batch committed.');
              batch = firestore.batch();
              batchCounter = 0;
              await Future.delayed(const Duration(milliseconds: 50));
            }
          }

          if (_processedProductTitleCount % 100 == 0 && mounted) {
            setState(() {
              _backfillProductTitleStatus =
                  'Processing... (Processed: $_processedProductTitleCount, Updated: $_backfilledProductTitleCount)';
            });
          }
        }
        if (!mounted) return;
        setState(() {
          _backfillProductTitleStatus =
              'Finished processing batch. (Total Processed: $_processedProductTitleCount, Total Updated: $_backfilledProductTitleCount)';
        });
      }

      if (batchCounter > 0) {
        if (!mounted) return;
        setState(() {
          _backfillProductTitleStatus =
              'Committing final product title backfill batch...';
        });
        log(
          'Committing final product title backfill batch ($batchCounter operations)...',
        );
        await batch.commit();
        log('Final product title backfill batch committed.');
      }

      if (mounted) {
        setState(() {
          _isBackfillingProductTitle = false;
          _backfillProductTitleStatus =
              'Product title backfill complete! Processed: $_processedProductTitleCount, Updated: $_backfilledProductTitleCount';
          _backfillProductTitleSuccess = true;
        });
      }
    } catch (e, s) {
      log('Error during product title backfill: $e', stackTrace: s);
      if (mounted) {
        setState(() {
          _isBackfillingProductTitle = false;
          _backfillProductTitleStatus =
              'Error during product title backfill: $e. Processed: $_processedProductTitleCount, Updated: $_backfilledProductTitleCount';
          _backfillProductTitleSuccess = false;
        });
      }
    }
  }

  /// Calls the deployed callable backfill_search_index to populate questSearchIndex
  Future<void> _runBackfillSearchIndex() async {
    setState(() {
      _isBackfillingSearchIndex = true;
      _backfillSearchStatus = 'Starting search index backfill...';
      _backfillSearchProcessed = 0;
      _backfillSearchSuccess = false;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'backfill_search_index',
      );
      final resp = await callable.call(<String, dynamic>{});
      final data = Map<String, dynamic>.from(resp.data ?? {});
      final processed = data['processed'] as int? ?? 0;

      setState(() {
        _backfillSearchProcessed = processed;
        _backfillSearchStatus =
            'Backfill complete: processed $processed documents.';
        _backfillSearchSuccess = true;
        _isBackfillingSearchIndex = false;
      });
    } catch (e, s) {
      log('Error calling backfill_search_index: $e', stackTrace: s);
      setState(() {
        _isBackfillingSearchIndex = false;
        _backfillSearchStatus = 'Error during search backfill: $e';
        _backfillSearchSuccess = false;
      });
    }
  }

  /// Simple status check which queries the questSearchIndex count for sanity
  Future<void> _checkSearchIndexStatus() async {
    setState(() {
      _backfillSearchStatus = 'Checking search index status...';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('questSearchIndex')
          .limit(1)
          .get();
      final exists = snapshot.docs.isNotEmpty;
      final totalSnapshot = await firestore
          .collection('questSearchIndex')
          .count()
          .get();
      final total = totalSnapshot.count;

      setState(() {
        _backfillSearchStatus =
            'Index present: $exists — documents in index: $total';
        _backfillSearchSuccess = exists;
      });
    } catch (e, s) {
      log('Error checking search index status: $e', stackTrace: s);
      setState(() {
        _backfillSearchStatus = 'Error checking search index: $e';
        _backfillSearchSuccess = false;
      });
    }
  }

  /// Batch updates the game system for multiple quests
  Future<void> _runBatchUpdateGameSystem() async {
    final questIds = _batchQuestIdController.text
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final newGameSystem = _batchGameSystemController.text.trim();

    // Validation
    if (questIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least one quest ID.'),
          backgroundColor: null,
        ),
      );
      return;
    }

    if (newGameSystem.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a new game system name.'),
          backgroundColor: null,
        ),
      );
      return;
    }

    setState(() {
      _isBatchUpdatingGameSystem = true;
      _batchGameSystemStatus =
          'Starting batch update (${questIds.length} quests)...';
      _batchGameSystemSuccess = false;
      _batchGameSystemProcessed = 0;
      _batchGameSystemUpdated = 0;
    });

    final firestore = FirebaseFirestore.instance;
    const batchSize = 400; // Firestore batch limit
    int batchCounter = 0;
    WriteBatch batch = firestore.batch();

    try {
      for (int i = 0; i < questIds.length; i++) {
        final questId = questIds[i];
        _batchGameSystemProcessed = i + 1;

        if (!mounted) return;
        setState(() {
          _batchGameSystemStatus =
              'Processing ${_batchGameSystemProcessed}/${questIds.length} quests...';
        });

        final docRef = firestore.collection('questCards').doc(questId);
        final docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          log('Quest $questId does not exist, skipping...');
          continue;
        }

        // Update both gameSystem and standardizedGameSystem
        batch.update(docRef, {
          'gameSystem': newGameSystem,
          'standardizedGameSystem': newGameSystem,
          'gameSystem_lowercase': newGameSystem.toLowerCase(),
        });
        batchCounter++;
        _batchGameSystemUpdated++;

        if (batchCounter >= batchSize) {
          if (!mounted) return;
          setState(() {
            _batchGameSystemStatus =
                'Committing batch (${_batchGameSystemProcessed}/${questIds.length}, Updated: ${_batchGameSystemUpdated})...';
          });
          log('Committing batch update...');
          await batch.commit();
          log('Batch committed.');
          batch = firestore.batch();
          batchCounter = 0;
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Commit final batch
      if (batchCounter > 0) {
        if (!mounted) return;
        setState(() {
          _batchGameSystemStatus =
              'Committing final batch (${_batchGameSystemUpdated} quests)...';
        });
        log('Committing final batch ($batchCounter operations)...');
        await batch.commit();
        log('Final batch committed.');
      }

      if (mounted) {
        setState(() {
          _isBatchUpdatingGameSystem = false;
          _batchGameSystemStatus =
              'Batch update complete! Updated: ${_batchGameSystemUpdated}/${questIds.length} quests to "$newGameSystem"';
          _batchGameSystemSuccess = true;
        });

        // Clear the input fields on success
        _batchQuestIdController.clear();
        _batchGameSystemController.clear();
      }
    } catch (e, s) {
      log('Error during batch game system update: $e', stackTrace: s);
      if (mounted) {
        setState(() {
          _isBatchUpdatingGameSystem = false;
          _batchGameSystemStatus =
              'Error during batch update: $e. Processed: ${_batchGameSystemProcessed}, Updated: ${_batchGameSystemUpdated}';
          _batchGameSystemSuccess = false;
        });
      }
    }
  }
}
