import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/backfill_stats.dart';
import '../quest_card/quest_card.dart';
import '../services/firestore_service.dart';
import '../services/purchase_link_service.dart';

/// Controller for managing purchase link backfill operations
class PurchaseLinkBackfillController {
  final FirestoreService _firestoreService;
  final PurchaseLinkService _purchaseLinkService;

  /// Document ID for storing backfill state in Firestore
  static const String backfillStateDocId = 'purchase_link_backfill_state';

  /// Collection name for backfill state
  static const String backfillStateCollection = 'admin';

  /// Whether the backfill is currently running
  bool _isRunning = false;

  /// Whether the backfill should be paused
  bool _shouldPause = false;

  /// Create a new backfill controller
  PurchaseLinkBackfillController({
    FirestoreService? firestoreService,
    PurchaseLinkService? purchaseLinkService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _purchaseLinkService = purchaseLinkService ?? PurchaseLinkService();

  /// Process backfill of purchase links in batches
  ///
  /// [batchSize] is the number of records to process in each batch
  /// Returns a stream of BackfillStats for progress tracking
  Stream<BackfillStats> processBackfill({int batchSize = 20}) async* {
    if (_isRunning) {
      throw Exception('Backfill process is already running');
    }

    _isRunning = true;
    _shouldPause = false;

    try {
      // Get or create backfill state
      BackfillStats stats = await _getBackfillState();

      // If we're starting fresh, count total records
      if (stats.total == 0 || stats.processed >= stats.total) {
        final total = await _countQuestCardsWithoutLinks();
        stats = stats.copyWith(total: total, processed: 0);
        await _saveBackfillState(stats);
      }

      // No records to process
      if (stats.total == 0) {
        yield stats;
        return;
      }

      // Report initial stats
      yield stats;

      // Process in batches
      while (stats.processed < stats.total) {
        // Check if paused
        if (_shouldPause) {
          break;
        }

        // Get a batch of QuestCards without links
        final batch = await _getQuestCardsWithoutLinks(
          limit: batchSize,
          offset: stats.processed,
        );

        if (batch.isEmpty) {
          // No more records to process
          break;
        }

        // Process each QuestCard in the batch
        var batchStats = stats;
        for (final questCard in batch) {
          // Check if paused
          if (_shouldPause) {
            break;
          }

          try {
            // Skip if already has a link
            if (questCard.link != null && questCard.link!.isNotEmpty) {
              batchStats = batchStats.copyWith(
                processed: batchStats.processed + 1,
                skipped: batchStats.skipped + 1,
              );
              continue;
            }

            // Extract metadata for search
            final metadata = {
              'title': questCard.title ?? '',
              'publisher': questCard.publisher ?? '',
              'gameSystem': questCard.gameSystem ?? '',
            };

            // Search for purchase link
            final purchaseLink =
                await _purchaseLinkService.findPurchaseLink(metadata);

            // Update API calls count
            batchStats = batchStats.copyWith(apiCalls: batchStats.apiCalls + 1);

            // Update QuestCard if link found
            if (purchaseLink != null && purchaseLink.isNotEmpty) {
              questCard.link = purchaseLink;
              await _firestoreService.updateQuestCard(questCard.id!, questCard);

              batchStats = batchStats.copyWith(
                processed: batchStats.processed + 1,
                successful: batchStats.successful + 1,
              );
            } else {
              batchStats = batchStats.copyWith(
                processed: batchStats.processed + 1,
                failed: batchStats.failed + 1,
              );
            }
          } catch (e) {
            log('Error processing QuestCard ${questCard.id}: $e');
            batchStats = batchStats.copyWith(
              processed: batchStats.processed + 1,
              failed: batchStats.failed + 1,
            );
          }

          // Update and save state after each record
          stats = batchStats;
          await _saveBackfillState(stats);
          yield stats;
        }

        // Add a small delay between batches to avoid overloading
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      _isRunning = false;
    }
  }

  /// Pause the backfill process
  Future<void> pauseBackfill() async {
    _shouldPause = true;
  }

  /// Get the current backfill stats
  Future<BackfillStats> getCurrentStats() async {
    return _getBackfillState();
  }

  /// Reset the backfill process
  Future<void> resetBackfill() async {
    await _saveBackfillState(BackfillStats.empty());
  }

  /// Get the current backfill state from Firestore
  Future<BackfillStats> _getBackfillState() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(backfillStateCollection)
          .doc(backfillStateDocId)
          .get();

      if (doc.exists && doc.data() != null) {
        return BackfillStats.fromMap(doc.data()!);
      }
    } catch (e) {
      log('Error getting backfill state: $e');
    }

    return BackfillStats.empty();
  }

  /// Save the current backfill state to Firestore
  Future<void> _saveBackfillState(BackfillStats stats) async {
    try {
      await FirebaseFirestore.instance
          .collection(backfillStateCollection)
          .doc(backfillStateDocId)
          .set(stats.toMap());
    } catch (e) {
      log('Error saving backfill state: $e');
    }
  }

  /// Count QuestCards without purchase links
  Future<int> _countQuestCardsWithoutLinks() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('questCards')
          .where('link', isNull: true)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      log('Error counting QuestCards without links: $e');
      return 0;
    }
  }

  /// Get a batch of QuestCards without purchase links
  Future<List<QuestCard>> _getQuestCardsWithoutLinks({
    required int limit,
    required int offset,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('questCards')
          .where('link', isNull: true)
          .orderBy('title')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => QuestCard.fromJson(doc.data())..id = doc.id)
          .toList();
    } catch (e) {
      log('Error getting QuestCards without links: $e');
      return [];
    }
  }
}
