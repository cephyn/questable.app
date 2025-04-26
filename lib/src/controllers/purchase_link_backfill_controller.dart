import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/backfill_stats.dart';
import '../services/purchase_link_service.dart';
import '../config/config.dart';

/// Controller for handling the purchase link backfill process
class PurchaseLinkBackfillController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PurchaseLinkService _purchaseLinkService = PurchaseLinkService();

  StreamController<BackfillStats>? _statsStreamController;
  BackfillStats _currentStats = BackfillStats.empty();
  bool _isPaused = false;

  /// Process a batch of quest cards that need purchase links
  Stream<BackfillStats> processBackfill({int batchSize = 20}) async* {
    _isPaused = false;
    _statsStreamController = StreamController<BackfillStats>();

    try {
      // Validate configuration before starting
      if (Config.googleApiKey.isEmpty || Config.googleSearchEngineId.isEmpty) {
        log('ERROR: Google API Key or Search Engine ID is missing');
        throw Exception(
            'Google API configuration is incomplete. Please set up your API keys in Firebase Remote Config.');
      }

      // First approach: Get documents with null link field
      final QuerySnapshot nullLinkSnapshot = await _firestore
          .collection('questCards')
          .where('link', isNull: true)
          .get();

      // Second approach: Get documents with empty string link
      final QuerySnapshot emptyLinkSnapshot = await _firestore
          .collection('questCards')
          .where('link', isEqualTo: '')
          .get();

      // Third approach: Get a sample of documents to check for missing link field
      // Note: This is a workaround since Firestore doesn't support "field does not exist" queries
      final QuerySnapshot allDocsSnapshot = await _firestore
          .collection('questCards')
          .limit(500) // Limit to avoid excessive reads
          .get();

      // Filter locally for documents missing the link field entirely
      final missingLinkDocs = allDocsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return data != null && !data.containsKey('link');
      }).toList();

      // Combine all documents (avoiding duplicates)
      final Set<String> allDocIds = {};
      final List<QueryDocumentSnapshot> allDocsToProcess = [];

      // Helper function to add docs to our processing list
      void addDocsToProcess(List<QueryDocumentSnapshot> docs) {
        for (final doc in docs) {
          if (!allDocIds.contains(doc.id)) {
            allDocIds.add(doc.id);
            allDocsToProcess.add(doc);
          }
        }
      }

      // Add all docs from the three queries
      addDocsToProcess(nullLinkSnapshot.docs);
      addDocsToProcess(emptyLinkSnapshot.docs);
      addDocsToProcess(missingLinkDocs);

      final int totalDocsNeeding = allDocsToProcess.length;

      log('Found $totalDocsNeeding documents needing purchase links');
      log('- ${nullLinkSnapshot.docs.length} documents with null links');
      log('- ${emptyLinkSnapshot.docs.length} documents with empty links');
      log('- ${missingLinkDocs.length} documents without a link field (from sample)');

      // Update total count in stats
      _currentStats = _currentStats.copyWith(
        total: totalDocsNeeding,
      );

      // Yield initial stats
      yield _currentStats;

      if (totalDocsNeeding == 0) {
        log('No documents found that need purchase links');
        return;
      }

      // Process all documents in batches
      for (int i = 0; i < allDocsToProcess.length; i += batchSize) {
        if (_isPaused) break;

        final int currentBatch = (i ~/ batchSize) + 1;
        final int totalBatches = (allDocsToProcess.length / batchSize).ceil();
        log('Processing batch $currentBatch of $totalBatches');

        // Get the current batch
        final int endIdx = i + batchSize > allDocsToProcess.length
            ? allDocsToProcess.length
            : i + batchSize;
        final currentBatchDocs = allDocsToProcess.sublist(i, endIdx);

        log('Processing ${currentBatchDocs.length} documents in this batch');

        // Process each document in the batch
        for (final doc in currentBatchDocs) {
          if (_isPaused) break;

          try {
            final questCardData = doc.data() as Map<String, dynamic>;
            final String title = questCardData['productTitle'] ?? '';
            final String subtitle = questCardData['title'] ?? '';

            log('Processing document: ${doc.id}, title: $title, subtitle: $subtitle');

            // Skip if we don't have enough data
            if (title.isEmpty && subtitle.isEmpty) {
              log('Skipping document due to empty title and subtitle: ${doc.id}');
              _currentStats = _currentStats.copyWith(
                processed: _currentStats.processed + 1,
                skipped: _currentStats.skipped + 1,
              );
              yield _currentStats;
              continue;
            }

            // Search for purchase link
            log('Searching for purchase link for: $title');
            final String? purchaseLink =
                await _purchaseLinkService.findPurchaseLink(questCardData);

            // Update firestore with link if found
            if (purchaseLink != null && purchaseLink.isNotEmpty) {
              log('Found purchase link for ${doc.id}: $purchaseLink');
              await _firestore
                  .collection('questCards')
                  .doc(doc.id)
                  .update({'link': purchaseLink});

              // Update stats
              _currentStats = _currentStats.copyWith(
                processed: _currentStats.processed + 1,
                successful: _currentStats.successful + 1,
                apiCalls: _currentStats.apiCalls + 1,
              );
            } else {
              // Link not found
              log('No purchase link found for ${doc.id}');
              _currentStats = _currentStats.copyWith(
                processed: _currentStats.processed + 1,
                failed: _currentStats.failed + 1,
                apiCalls: _currentStats.apiCalls + 1,
              );
            }

            // Yield updated stats
            yield _currentStats;
          } catch (e) {
            // Handle individual document error
            log('Error processing document ${doc.id}: $e');
            _currentStats = _currentStats.copyWith(
              processed: _currentStats.processed + 1,
              failed: _currentStats.failed + 1,
            );
            yield _currentStats;
          }
        }

        // Brief delay to avoid hitting API rate limits
        log('Completed batch. Taking a short break to avoid rate limits.');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      // Handle overall process error
      log('Error in processBackfill: $e');
      rethrow;
    } finally {
      log('Backfill process completed or paused');
      await _statsStreamController?.close();
    }
  }

  /// Pause the backfill process
  Future<void> pauseBackfill() async {
    log('Pausing backfill process');
    _isPaused = true;
    await _statsStreamController?.close();
  }

  /// Get the current processing stats
  Future<BackfillStats> getCurrentStats() async {
    return _currentStats;
  }
}
