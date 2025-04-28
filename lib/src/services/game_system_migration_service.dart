import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/standard_game_system.dart';
import 'game_system_service.dart';
import 'game_system_mapper.dart';

/// Service for managing large-scale game system migrations
class GameSystemMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameSystemService _gameSystemService = GameSystemService();
  final GameSystemMapper _gameSystemMapper = GameSystemMapper();

  /// Reference to the questCards collection
  CollectionReference<Map<String, dynamic>> get questCards =>
      _firestore.collection('questCards');

  /// Reference to the migration_logs collection
  CollectionReference<Map<String, dynamic>> get migrationLogs =>
      _firestore.collection('migration_logs');

  /// Reference to migration_metrics collection for analytics
  CollectionReference<Map<String, dynamic>> get migrationMetrics =>
      _firestore.collection('migration_metrics');

  /// Get quest cards that need standardization
  ///
  /// Returns quest cards that either:
  /// - Have no standardizedGameSystem field
  /// - Have systemMigrationStatus = 'pending' or 'failed'
  Future<List<DocumentSnapshot>> getQuestCardsNeedingStandardization({
    int limit = 100,
    DocumentSnapshot? startAfter,
  }) async {
    // Can't use whereIn with null values, need to use separate queries
    final pendingOrFailedQuery = questCards.where('systemMigrationStatus',
        whereIn: ['pending', 'failed']).limit(limit);

    final nullStatusQuery =
        questCards.where('standardizedGameSystem', isNull: true).limit(limit);

    if (startAfter != null) {
      final withStartAfter1 =
          pendingOrFailedQuery.startAfterDocument(startAfter);
      final withStartAfter2 = nullStatusQuery.startAfterDocument(startAfter);

      final results1 = await withStartAfter1.get();
      final results2 = await withStartAfter2.get();

      return [...results1.docs, ...results2.docs];
    }

    final results1 = await pendingOrFailedQuery.get();
    final results2 = await nullStatusQuery.get();

    return [...results1.docs, ...results2.docs];
  }

  /// Get quest cards that use a specific game system name
  ///
  /// This is useful for finding all quest cards that would be affected
  /// by standardizing a specific game system
  Future<List<DocumentSnapshot>> getQuestCardsByGameSystem(
      String gameSystemName,
      {int limit = 100}) async {
    final snapshot = await questCards
        .where('gameSystem', isEqualTo: gameSystemName)
        .limit(limit)
        .get();

    return snapshot.docs;
  }

  /// Apply a standard game system to multiple quest cards
  ///
  /// Returns the number of successfully updated quest cards
  Future<int> applyStandardToQuests(StandardGameSystem standardSystem,
      List<DocumentSnapshot> questCards) async {
    int successCount = 0;
    WriteBatch batch = _firestore.batch();
    final timestamp = FieldValue.serverTimestamp();
    final migrationId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create a migration log
    final logRef = migrationLogs.doc(migrationId);
    batch.set(logRef, {
      'timestamp': timestamp,
      'standardSystem': standardSystem.id,
      'standardName': standardSystem.standardName,
      'affectedCount': questCards.length,
      'status': 'in_progress',
    });

    // Process quest cards in batches (max 500 per batch)
    for (var i = 0; i < questCards.length; i++) {
      final questCard = questCards[i];
      final data = questCard.data() as Map<String, dynamic>?;

      if (data != null) {
        final originalGameSystem = data['gameSystem'];

        batch.update(questCard.reference, {
          'standardizedGameSystem': standardSystem.standardName,
          'systemMigrationStatus': 'completed',
          'systemMigrationTimestamp': timestamp,
          'migrationId': migrationId,
        });

        successCount++;

        // Firestore batches limited to 500 operations
        if (i > 0 && i % 499 == 0) {
          await batch.commit();

          // Start a new batch
          batch = _firestore.batch();
        }
      }
    }

    // Commit any remaining operations
    if (successCount > 0) {
      await batch.commit();

      // Update the migration log
      await logRef.update({
        'status': 'completed',
        'successCount': successCount,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Record metrics for this migration
      await _recordMigrationMetrics(standardSystem.standardName, successCount);
    }

    return successCount;
  }

  /// Run an automated migration with intelligent system matching
  ///
  /// This is more advanced than applyStandardToQuests as it will:
  /// 1. Find the best matching standard system for each quest
  /// 2. Apply updates only for high-confidence matches
  /// 3. Track low-confidence matches for manual review
  Future<Map<String, int>> runAutomatedMigration({
    int batchSize = 100,
    double confidenceThreshold = 0.75,
    bool dryRun = false,
  }) async {
    int processed = 0;
    int successful = 0;
    int skipped = 0;
    int failed = 0;
    int lowConfidence = 0;

    final migrationId = 'auto_${DateTime.now().millisecondsSinceEpoch}';

    // Create a migration log
    await migrationLogs.doc(migrationId).set({
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'automated',
      'status': 'in_progress',
      'confidenceThreshold': confidenceThreshold,
      'isDryRun': dryRun,
    });

    try {
      // Get quest cards needing standardization
      DocumentSnapshot? lastDoc;
      List<DocumentSnapshot> batch;

      // Process in batches to avoid memory issues
      do {
        batch = await getQuestCardsNeedingStandardization(
          limit: batchSize,
          startAfter: lastDoc,
        );

        if (batch.isNotEmpty) {
          lastDoc = batch.last;

          // Process each quest card
          WriteBatch writeBatch = _firestore.batch();
          List<Map<String, dynamic>> lowConfidenceMatches = [];
          int batchCounter = 0;

          for (final doc in batch) {
            processed++;

            try {
              final data = doc.data() as Map<String, dynamic>?;

              if (data != null && data['gameSystem'] is String) {
                final gameSystem = data['gameSystem'] as String;

                // Find the best matching standard system
                final mappingResult =
                    await _gameSystemMapper.findBestMatch(gameSystem);

                if (mappingResult.system != null) {
                  if (mappingResult.confidence >= confidenceThreshold) {
                    if (!dryRun) {
                      // Update this document
                      writeBatch.update(doc.reference, {
                        'standardizedGameSystem':
                            mappingResult.system!.standardName,
                        'systemMigrationStatus': 'completed',
                        'systemMigrationConfidence': mappingResult.confidence,
                        'systemMigrationMatchType': mappingResult.matchType,
                        'systemMigrationTimestamp':
                            FieldValue.serverTimestamp(),
                        'migrationId': migrationId,
                      });

                      batchCounter++;
                      successful++;

                      // Commit batch when it reaches the limit
                      if (batchCounter >= 499) {
                        await writeBatch.commit();
                        writeBatch = _firestore.batch();
                        batchCounter = 0;

                        // Update log with progress
                        await migrationLogs.doc(migrationId).update({
                          'processed': processed,
                          'successful': successful,
                        });

                        // Add a small delay to prevent rate limiting
                        await Future.delayed(const Duration(milliseconds: 100));
                      }
                    } else {
                      // Just count it as successful in dry run mode
                      successful++;
                    }
                  } else {
                    // Low confidence match
                    lowConfidence++;
                    if (!dryRun) {
                      // Store for manual review
                      lowConfidenceMatches.add({
                        'questId': doc.id,
                        'originalSystem': gameSystem,
                        'suggestedSystem': mappingResult.system!.standardName,
                        'confidence': mappingResult.confidence,
                        'matchType': mappingResult.matchType,
                      });

                      // Mark for manual review
                      writeBatch.update(doc.reference, {
                        'systemMigrationStatus': 'needs_review',
                        'suggestedSystem': mappingResult.system!.standardName,
                        'systemMigrationConfidence': mappingResult.confidence,
                        'migrationId': migrationId,
                      });

                      batchCounter++;
                    }
                  }
                } else {
                  // No match found
                  skipped++;
                  if (!dryRun) {
                    writeBatch.update(doc.reference, {
                      'systemMigrationStatus': 'no_match',
                      'migrationId': migrationId,
                    });
                    batchCounter++;
                  }
                }
              } else {
                skipped++;
              }
            } catch (e) {
              failed++;
              if (!dryRun) {
                writeBatch.update(doc.reference, {
                  'systemMigrationStatus': 'failed',
                  'systemMigrationError': e.toString(),
                  'migrationId': migrationId,
                });
                batchCounter++;
              }
            }
          }

          // Commit any remaining operations
          if (!dryRun && batchCounter > 0) {
            await writeBatch.commit();
          }

          // Store low confidence matches for manual review
          if (!dryRun && lowConfidenceMatches.isNotEmpty) {
            await migrationLogs
                .doc(migrationId)
                .collection('low_confidence_matches')
                .doc('batch_${DateTime.now().millisecondsSinceEpoch}')
                .set({
              'matches': lowConfidenceMatches,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }

        // Update log regularly
        if (!dryRun) {
          await migrationLogs.doc(migrationId).update({
            'processed': processed,
            'successful': successful,
            'failed': failed,
            'skipped': skipped,
            'lowConfidence': lowConfidence,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      } while (batch.isNotEmpty);

      // Update the final status
      await migrationLogs.doc(migrationId).update({
        'status': 'completed',
        'processed': processed,
        'successful': successful,
        'failed': failed,
        'skipped': skipped,
        'lowConfidence': lowConfidence,
        'completedAt': FieldValue.serverTimestamp(),
      });

      return {
        'processed': processed,
        'successful': successful,
        'failed': failed,
        'skipped': skipped,
        'lowConfidence': lowConfidence,
      };
    } catch (e) {
      // Log the error
      await migrationLogs.doc(migrationId).update({
        'status': 'error',
        'error': e.toString(),
        'processed': processed,
        'successful': successful,
        'failed': failed,
        'skipped': skipped,
        'lowConfidence': lowConfidence,
      });

      debugPrint('Error in automated migration: $e');
      rethrow;
    }
  }

  /// Process low confidence matches that need manual review
  Future<List<Map<String, dynamic>>> getLowConfidenceMatches(
      String migrationId) async {
    final results = <Map<String, dynamic>>[];

    final matchesSnapshot = await migrationLogs
        .doc(migrationId)
        .collection('low_confidence_matches')
        .get();

    for (final doc in matchesSnapshot.docs) {
      final data = doc.data();
      if (data.containsKey('matches') && data['matches'] is List) {
        for (final match in data['matches']) {
          if (match is Map<String, dynamic>) {
            results.add(match);
          }
        }
      }
    }

    return results;
  }

  /// Apply manual resolution to low confidence matches
  Future<int> resolveManualMatches(
      String migrationId, Map<String, String> resolutions) async {
    int count = 0;
    WriteBatch batch = _firestore.batch();
    int batchCounter = 0;

    // For each quest ID -> standard system mapping
    for (final entry in resolutions.entries) {
      final questId = entry.key;
      final standardName = entry.value;

      // Find the standard system by name
      final standardSystem =
          await _gameSystemService.findGameSystemByName(standardName);

      if (standardSystem != null) {
        batch.update(questCards.doc(questId), {
          'standardizedGameSystem': standardName,
          'systemMigrationStatus': 'completed',
          'systemMigrationTimestamp': FieldValue.serverTimestamp(),
          'manuallyResolved': true,
          'migrationId': migrationId,
        });

        count++;
        batchCounter++;

        // Add successful mapping to the system's aliases to improve future matching
        final questDoc = await questCards.doc(questId).get();
        final originalGameSystem = questDoc.data()?['gameSystem'];

        if (originalGameSystem != null && originalGameSystem is String) {
          await _gameSystemMapper.learnFromManualMapping(
              originalGameSystem, standardSystem);
        }

        // Commit when batch reaches limit
        if (batchCounter >= 499) {
          await batch.commit();
          batch = _firestore.batch();
          batchCounter = 0;
        }
      }
    }

    // Commit any remaining operations
    if (batchCounter > 0) {
      await batch.commit();
    }

    // Update the migration log
    await migrationLogs.doc(migrationId).update({
      'manuallyResolved': count,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    return count;
  }

  /// Get the status of a migration
  Future<Map<String, dynamic>?> getMigrationStatus(String migrationId) async {
    final doc = await migrationLogs.doc(migrationId).get();
    return doc.data();
  }

  /// Get recent migration logs
  Future<List<Map<String, dynamic>>> getRecentMigrations(
      {int limit = 10}) async {
    final snapshot = await migrationLogs
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()..addAll({'id': doc.id}))
        .toList();
  }

  /// Undo a migration by migration ID
  ///
  /// This will reset the standardizedGameSystem field on all affected quest cards
  Future<int> undoMigration(String migrationId) async {
    // Get all quest cards affected by this migration
    final snapshot =
        await questCards.where('migrationId', isEqualTo: migrationId).get();

    if (snapshot.docs.isEmpty) {
      return 0;
    }

    int undoCount = 0;
    WriteBatch batch = _firestore.batch();

    // Process quest cards in batches
    for (var i = 0; i < snapshot.docs.length; i++) {
      final questCard = snapshot.docs[i];

      batch.update(questCard.reference, {
        'standardizedGameSystem': FieldValue.delete(),
        'systemMigrationStatus': 'pending',
        'systemMigrationTimestamp': FieldValue.delete(),
        'migrationId': FieldValue.delete(),
        'systemMigrationConfidence': FieldValue.delete(),
        'systemMigrationMatchType': FieldValue.delete(),
        'manuallyResolved': FieldValue.delete(),
        'suggestedSystem': FieldValue.delete(),
      });

      undoCount++;

      // Firestore batches limited to 500 operations
      if (i > 0 && i % 499 == 0) {
        await batch.commit();

        // Start a new batch
        batch = _firestore.batch();
      }
    }

    // Commit any remaining operations
    if (undoCount > 0) {
      await batch.commit();

      // Update the migration log
      await migrationLogs.doc(migrationId).update({
        'status': 'undone',
        'undoneCount': undoCount,
        'undoneAt': FieldValue.serverTimestamp(),
      });
    }

    return undoCount;
  }

  /// Schedule a migration to run at a future time
  Future<String> scheduleMigration({
    required DateTime scheduledTime,
    int batchSize = 100,
    double confidenceThreshold = 0.75,
  }) async {
    final migrationId = 'scheduled_${DateTime.now().millisecondsSinceEpoch}';

    await migrationLogs.doc(migrationId).set({
      'timestamp': FieldValue.serverTimestamp(),
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'batchSize': batchSize,
      'confidenceThreshold': confidenceThreshold,
      'status': 'scheduled',
      'type': 'automated',
    });

    return migrationId;
  }

  /// Record metrics about a migration for analytics
  Future<void> _recordMigrationMetrics(String standardName, int count) async {
    final dateStr =
        DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

    // Update migration metrics for this date and system
    await migrationMetrics.doc(dateStr).set({
      'date': dateStr,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update the count for this standard system
    await migrationMetrics
        .doc(dateStr)
        .collection('systems')
        .doc(standardName)
        .set({
      'standardName': standardName,
      'count': FieldValue.increment(count),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update total metrics
    await migrationMetrics.doc(dateStr).update({
      'totalMigrated': FieldValue.increment(count),
    });
  }

  /// Count quest cards with and without standardization
  Future<Map<String, int>> getStandardizationStats() async {
    final standardizedSnapshot = await questCards
        .where('systemMigrationStatus', isEqualTo: 'completed')
        .count()
        .get();

    final pendingSnapshot = await questCards
        .where('systemMigrationStatus', isEqualTo: 'pending')
        .count()
        .get();

    final failedSnapshot = await questCards
        .where('systemMigrationStatus', isEqualTo: 'failed')
        .count()
        .get();

    final needsReviewSnapshot = await questCards
        .where('systemMigrationStatus', isEqualTo: 'needs_review')
        .count()
        .get();

    final totalSnapshot = await questCards.count().get();

    // Extract the count values from the AggregateQuerySnapshot objects
    final standardizedCount = standardizedSnapshot.count ?? 0;
    final pendingCount = pendingSnapshot.count ?? 0;
    final failedCount = failedSnapshot.count ?? 0;
    final needsReviewCount = needsReviewSnapshot.count ?? 0;
    final totalCount = totalSnapshot.count ?? 0;

    return {
      'standardized': standardizedCount,
      'pending': pendingCount,
      'failed': failedCount,
      'needsReview': needsReviewCount,
      'total': totalCount,
      'unprocessed': totalCount -
          standardizedCount -
          pendingCount -
          failedCount -
          needsReviewCount,
    };
  }

  /// Get migration metrics for a date range
  Future<List<Map<String, dynamic>>> getMigrationMetrics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = <Map<String, dynamic>>[];

    // Convert dates to ISO strings (YYYY-MM-DD)
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];

    // Query metrics in the date range
    final snapshot = await migrationMetrics
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
        .orderBy(FieldPath.documentId)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      data['systemDetails'] = [];

      // Get system details for this date
      final systemsSnapshot = await doc.reference.collection('systems').get();
      final systemDetails =
          systemsSnapshot.docs.map((systemDoc) => systemDoc.data()).toList();

      data['systemDetails'] = systemDetails;
      results.add(data);
    }

    return results;
  }
}
