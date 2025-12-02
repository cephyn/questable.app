import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quest_cards/src/filters/filter_state.dart';
import 'package:quest_cards/src/services/email_service.dart';
import 'package:rxdart/rxdart.dart'; // Import rxdart

import '../quest_card/quest_card.dart';
import '../user/local_user.dart';

class FirestoreService {
  //get collection of quest cards
  final CollectionReference questCards =
      FirebaseFirestore.instance.collection('questCards');
  final CollectionReference users =
      FirebaseFirestore.instance.collection('users');
  final EmailService emailService = EmailService();

  // Helper to fetch owned quest IDs for a user
  Future<List<String>> _fetchOwnedQuestIds(String userId) async {
    try {
      final snapshot = await users.doc(userId).collection('ownedQuests').get();
      // Check if the collection exists and has documents
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) => doc.id).toList();
      } else {
        // Return an empty list if the collection is empty or doesn't exist
        return [];
      }
    } catch (e) {
      log('Error fetching owned quest IDs for user $userId: $e');
      return []; // Return empty list on error
    }
  }

  //create
  Future<String> addQuestCard(QuestCard questCard) async {
    String docId = "";
    await questCards.add({
      'id': questCard.generateUniqueHash(),
      'title':
          questCard.title?.toLowerCase(), // Ensure title is stored lowercase
      'productTitle': questCard.productTitle,
      'gameSystem': questCard.gameSystem,
        'standardizedGameSystem': questCard.standardizedGameSystem,
      'gameSystem_lowercase':
          questCard.gameSystem?.toLowerCase(), // Add lowercase field
      'edition': questCard.edition,
      'level': questCard.level,
      'pageLength': questCard.pageLength,
      'authors': questCard.authors,
      'publisher': questCard.publisher,
      'publicationYear': questCard.publicationYear,
      'setting': questCard.setting,
      'environments': questCard.environments,
      'link': questCard.link?.toString(),
      'bossVillains': questCard.bossVillains,
      'commonMonsters': questCard.commonMonsters,
      'notableItems': questCard.notableItems,
      'summary': questCard.summary,
      'timestamp': Timestamp.now(),
      'genre': questCard.genre,
      'classification': questCard.classification,
      'uploadedBy': questCard.uploadedBy,
      'isPublic': questCard.isPublic, // Add isPublic field
        'systemMigrationStatus': questCard.systemMigrationStatus,
        'systemMigrationTimestamp': questCard.systemMigrationTimestamp != null
          ? Timestamp.fromDate(questCard.systemMigrationTimestamp!)
          : null,
        'uploaderEmail': questCard.uploaderEmail,
        'uploadedTimestamp':
          questCard.uploadedTimestamp != null
            ? Timestamp.fromDate(questCard.uploadedTimestamp!)
            : null,
    }).then((DocumentReference ref) {
      docId = ref.id;
    });
    //print(docId);
    return docId;
  }

  //read
  /// Gets a stream of quest cards.
  /// Can filter by specific docIds (e.g., from search) or fetch all.
  /// Applies filters from filterState, including ownership if userId is provided.
  ///
  /// @param docIds List of specific document IDs to fetch. If empty, fetches all matching filters.
  /// @param filterState Optional filter state to apply filtering.
  /// @param userId Optional user ID required for ownership filtering.
  Stream<List<QueryDocumentSnapshot<Object?>>> getQuestCardsStream(
    List<String> docIds, {
    FilterState? filterState,
    String? userId, // Added userId for ownership filter
  }) async* {
    // Changed to async* to use await inside
    Query baseQuery = questCards; // Start with the base collection
    List<String> targetDocIds =
        List.from(docIds); // IDs to eventually query with whereIn
    bool useWhereInQuery =
        docIds.isNotEmpty; // Start assuming we filter by provided docIds
    FilterState? effectiveFilterState =
        filterState?.clone(); // Clone to modify locally

    FilterCriteria? ownershipFilter;
    if (userId != null && effectiveFilterState != null) {
      ownershipFilter =
          effectiveFilterState.getFilterForField(ownershipFilterField);
      if (ownershipFilter != null) {
        // Remove ownership filter so it's not applied by applyFiltersToQuery
        effectiveFilterState.removeFilterByField(ownershipFilterField);
      }
    }

    // --- Ownership Filter Logic ---
    if (userId != null && ownershipFilter != null) {
      List<String> ownedQuestIds = await _fetchOwnedQuestIds(userId);
      log('Ownership filter active. User: $userId, Owned IDs: ${ownedQuestIds.length}, Filter: ${ownershipFilter.value}');

      if (ownershipFilter.value == 'owned') {
        if (ownedQuestIds.isEmpty) {
          // User owns nothing, so result is empty
          yield []; // Emit empty list and stop
          return;
        }
        if (useWhereInQuery) {
          // Intersect provided docIds with ownedQuestIds
          targetDocIds =
              targetDocIds.where((id) => ownedQuestIds.contains(id)).toList();
          if (targetDocIds.isEmpty) {
            yield []; // Emit empty list and stop
            return;
          }
        } else {
          // Filtering all quests, target is the owned list
          targetDocIds = ownedQuestIds;
          useWhereInQuery = true; // Now we must use whereIn
        }
      } else if (ownershipFilter.value == 'unowned') {
        if (ownedQuestIds.isEmpty) {
          // User owns nothing, so all quests are unowned. Proceed without ID filtering.
          // targetDocIds remains as it was (either original docIds or empty)
          // useWhereInQuery remains as it was
        } else {
          if (useWhereInQuery) {
            // Remove owned IDs from the provided docIds
            targetDocIds = targetDocIds
                .where((id) => !ownedQuestIds.contains(id))
                .toList();
            if (targetDocIds.isEmpty) {
              yield []; // Emit empty list and stop
              return;
            }
          } else {
            // Filtering all quests: Use whereNotIn if possible (<= 30 IDs)
            if (ownedQuestIds.length <= 30) {
              log('Applying whereNotIn for unowned filter.');
              baseQuery = baseQuery.where(FieldPath.documentId,
                  whereNotIn: ownedQuestIds);
              // We applied the filter directly to baseQuery, don't use whereIn later
              useWhereInQuery = false;
            } else {
              // Limitation: Cannot efficiently filter "all unowned" if user owns > 30 quests.
              // For now, we log and proceed without this specific filter.
              // A more robust solution might involve fetching all IDs and filtering client-side,
              // or fetching owned IDs and then querying in batches, which is complex.
              log('Warning: Cannot apply "unowned" filter efficiently as user owns > 30 quests. Returning all quests matching other filters.');
              // Proceed without adding whereNotIn, effectively ignoring the unowned filter in this edge case.
              useWhereInQuery =
                  false; // Ensure we don't accidentally use whereIn later
            }
          }
        }
      }
    }
    // --- End Ownership Filter Logic ---

    // Apply standard filters (excluding ownership)
    if (effectiveFilterState != null && effectiveFilterState.hasFilters) {
      log('Applying standard filters: ${effectiveFilterState.filters}');
      baseQuery = effectiveFilterState.applyFiltersToQuery(baseQuery);
    }

    // Apply sorting (default or from filters if specified)
    // Note: applyFiltersToQuery might add sorting. If not, add a default.
    // Firestore requires the first orderBy field to match the inequality/whereIn field.
    if (!useWhereInQuery) {
      baseQuery = baseQuery.orderBy('title');
      log('Applied default title sort.');
    } else {
      log('Skipping default sort due to whereIn filter.');
      // If useWhereInQuery is true, results might not be sorted unless
      // the filter state itself included an orderBy on FieldPath.documentId
    }

    // --- Query Execution ---
    if (useWhereInQuery) {
      // Use whereIn with targetDocIds, handling chunking
      const int limit = 30;
      if (targetDocIds.isEmpty) {
        // This case should ideally be caught earlier, but double-check
        yield [];
        return;
      }

      if (targetDocIds.length <= limit) {
        log('Executing single whereIn query for ${targetDocIds.length} IDs.');
        Query finalQuery =
            baseQuery.where(FieldPath.documentId, whereIn: targetDocIds);
        yield* finalQuery
            .snapshots()
            .map((snapshot) => snapshot.docs); // Use yield*
      } else {
        log('Executing chunked whereIn query for ${targetDocIds.length} IDs.');
        List<Stream<List<QueryDocumentSnapshot>>> streams = [];
        for (int i = 0; i < targetDocIds.length; i += limit) {
          List<String> chunk = targetDocIds.sublist(
              i,
              i + limit > targetDocIds.length
                  ? targetDocIds.length
                  : i + limit);
          if (chunk.isNotEmpty) {
            // Apply the whereIn to the baseQuery *with filters already applied*
            Query chunkQuery =
                baseQuery.where(FieldPath.documentId, whereIn: chunk);
            streams
                .add(chunkQuery.snapshots().map((snapshot) => snapshot.docs));
          }
        }

        // Combine streams and yield results
        yield* Rx.combineLatest<List<QueryDocumentSnapshot<Object?>>,
            List<QueryDocumentSnapshot<Object?>>>(streams, (listOfDocLists) {
          final combinedDocs = listOfDocLists.expand((list) => list).toList();
          // Deduplicate (important if original docIds had duplicates or logic error)
          final uniqueDocs = <String, QueryDocumentSnapshot<Object?>>{};
          for (final doc in combinedDocs) {
            uniqueDocs[doc.id] = doc;
          }
          log('Combined ${uniqueDocs.length} unique docs from chunks.');
          // Sort combined results by title if default sort was skipped due to whereIn
          var sortedDocs = uniqueDocs.values.toList();
          try {
            sortedDocs.sort((a, b) {
              var titleA =
                  (a.data() as Map<String, dynamic>?)?['title'] as String? ??
                      '';
              var titleB =
                  (b.data() as Map<String, dynamic>?)?['title'] as String? ??
                      '';
              return titleA.compareTo(titleB);
            });
          } catch (e) {
            log("Error sorting combined docs by title: $e");
          }
          return sortedDocs;
        });
      }
    } else {
      // Execute the baseQuery (which might have whereNotIn or just standard filters)
      log('Executing query without whereIn.');
      yield* baseQuery
          .snapshots()
          .map((snapshot) => snapshot.docs); // Use yield*
    }
  }

  /// Gets a stream of all public quest cards. Ignores ownership filters.
  Stream<List<QueryDocumentSnapshot<Object?>>> getPublicQuestCardsStream(
      {FilterState? filterState}) {
    Query query = questCards.where('isPublic',
        isEqualTo: true); // Base query for public cards

    // Clone filter state and remove ownership filter if present
    FilterState? effectiveFilterState = filterState?.clone();
    effectiveFilterState
        ?.removeFilterByField(ownershipFilterField); // Ignore ownership

    // Apply remaining filters
    if (effectiveFilterState != null && effectiveFilterState.hasFilters) {
      query = effectiveFilterState.applyFiltersToQuery(query);
    }

    // Apply default sorting
    query = query.orderBy('title');

    return query.snapshots().map((snapshot) => snapshot.docs);
  }

  /// Gets the count of public quest cards. Ignores ownership filters.
  Future<int> getPublicQuestCardCount({FilterState? filterState}) async {
    Query query = questCards.where('isPublic',
        isEqualTo: true); // Base query for public cards

    // Clone filter state and remove ownership filter if present
    FilterState? effectiveFilterState = filterState?.clone();
    effectiveFilterState
        ?.removeFilterByField(ownershipFilterField); // Ignore ownership

    // Apply remaining filters
    if (effectiveFilterState != null && effectiveFilterState.hasFilters) {
      query = effectiveFilterState.applyFiltersToQuery(query);
    }

    try {
      var res = await query.count().get();
      return res.count ?? 0;
    } catch (e) {
      log("Error getting public quest card count: $e");
      return 0;
    }
  }

  /// Fetches a batch of public quest cards with pagination and filtering.
  /// Ignores ownership filters.
  Future<List<QueryDocumentSnapshot>> getPublicQuestCardsBatch(
    int limit,
    DocumentSnapshot? startAfterDocument, {
    FilterState? filterState,
  }) async {
    Query query = questCards.where('isPublic', isEqualTo: true);

    // Clone filter state and remove ownership filter if present
    FilterState? effectiveFilterState = filterState?.clone();
    effectiveFilterState
        ?.removeFilterByField(ownershipFilterField); // Ignore ownership

    // Apply remaining filters
    if (effectiveFilterState != null && effectiveFilterState.hasFilters) {
      query = effectiveFilterState.applyFiltersToQuery(query);
    }

    // Apply default sorting (important for consistent pagination)
    query = query.orderBy('title'); // Or another consistent field

    // Apply pagination
    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    // Apply limit
    query = query.limit(limit);

    try {
      final snapshot = await query.get();
      return snapshot.docs;
    } catch (e) {
      log("Error fetching public quest card batch: $e");
      // Log specific Firestore errors if helpful
      if (e is FirebaseException) {
        log("Firestore error code: ${e.code}, message: ${e.message}");
      }
      return []; // Return empty list on error
    }
  }

  /// Gets the count of quest cards, potentially applying ownership filter.
  /// Note: Count may be inaccurate for 'Owned'/'Unowned' filters if user owns > 30 quests.
  Future<int> getQuestCardsCount(
      {FilterState? filterState, String? userId}) async {
    Query query = questCards; // Start with base collection
    FilterState? effectiveFilterState = filterState?.clone(); // Clone to modify

    FilterCriteria? ownershipFilter;
    if (userId != null && effectiveFilterState != null) {
      ownershipFilter =
          effectiveFilterState.getFilterForField(ownershipFilterField);
      if (ownershipFilter != null) {
        // Remove ownership filter so it's not applied by applyFiltersToQuery
        effectiveFilterState.removeFilterByField(ownershipFilterField);
      }
    }

    // Apply standard filters first
    if (effectiveFilterState != null && effectiveFilterState.hasFilters) {
      query = effectiveFilterState.applyFiltersToQuery(query);
    }

    // Apply ownership filter if applicable and possible
    if (userId != null && ownershipFilter != null) {
      List<String> ownedQuestIds = await _fetchOwnedQuestIds(userId);

      if (ownershipFilter.value == 'owned') {
        if (ownedQuestIds.isEmpty) return 0; // Owns nothing, count is 0
        if (ownedQuestIds.length <= 30) {
          query = query.where(FieldPath.documentId, whereIn: ownedQuestIds);
        } else {
          log('Warning: Count for "Owned" filter may be inaccurate (user owns > 30 quests).');
          // Cannot apply whereIn filter for count(). Returning count matching *other* filters.
          // Or return -1 to indicate inaccuracy? Let's return the count without this filter for now.
        }
      } else if (ownershipFilter.value == 'unowned') {
        if (ownedQuestIds.isEmpty) {
          // Owns nothing, all quests are unowned. No ID filter needed.
        } else if (ownedQuestIds.length <= 30) {
          query = query.where(FieldPath.documentId, whereNotIn: ownedQuestIds);
        } else {
          log('Warning: Count for "Unowned" filter may be inaccurate (user owns > 30 quests).');
          // Cannot apply whereNotIn filter for count(). Returning count matching *other* filters.
        }
      }
    }

    // Get the count
    try {
      var res = await query.count().get();
      return res.count ?? 0;
    } catch (e) {
      log("Error getting quest card count: $e");
      // Log specific Firestore errors if helpful
      if (e is FirebaseException) {
        log("Firestore error code: ${e.code}, message: ${e.message}");
      }
      return 0; // Return 0 on error
    }
  }

  Stream<DocumentSnapshot> getQuestCardStream(String docId) {
    return questCards.doc(docId).snapshots();
  }

  // Method to fetch similar quests for a given quest ID
  Future<List<Map<String, dynamic>>> getSimilarQuests(String questId) async {
    try {
      final snapshot = await questCards
          .doc(questId)
          .collection('similarQuests')
          .orderBy('score', descending: true) // Scores are 0.0 to 1.0
          .limit(10) // Already limited to 10 by backend, but good practice
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          // The document ID is the similar quest's ID
          // The document data contains the 'score'
          return {
            'questId': doc.id,
            'score': doc.data()['score'] as double,
            // Add other fields if they exist, e.g., 'genre', 'questName'
            // For now, assuming only score is directly in similarQuests,
            // and we'll fetch details separately.
          };
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      log('Error fetching similar quests for quest $questId: $e');
      return []; // Return empty list on error
    }
  }

  //update
  Future<void> updateQuestCard(String docId, QuestCard questCard) {
    log("Updating quest card with ID: $docId");
    log(questCard.toJson().toString());
    return questCards.doc(docId).update({
      'id': questCard.id,
      'title':
          questCard.title?.toLowerCase(), // Ensure title is stored lowercase
      'productTitle': questCard.productTitle,
      'gameSystem': questCard.gameSystem,
      'gameSystem_lowercase':
          questCard.gameSystem?.toLowerCase(), // Add/Update lowercase field
      'edition': questCard.edition,
      'level': questCard.level,
      'pageLength': questCard.pageLength,
      'authors': questCard.authors,
      'publisher': questCard.publisher,
      'publicationYear': questCard.publicationYear,
      'setting': questCard.setting,
      'environments': questCard.environments,
      'link': questCard.link?.toString(),
      'bossVillains': questCard.bossVillains,
      'commonMonsters': questCard.commonMonsters,
      'notableItems': questCard.notableItems,
      'summary': questCard.summary,
      'timestamp': Timestamp.now(),
      'genre': questCard.genre,
      'classification': questCard.classification,
      'uploadedBy': questCard.uploadedBy,
      'isPublic': questCard.isPublic, // Add isPublic field
        'standardizedGameSystem': questCard.standardizedGameSystem,
        'systemMigrationStatus': questCard.systemMigrationStatus,
        'systemMigrationTimestamp': questCard.systemMigrationTimestamp != null
          ? Timestamp.fromDate(questCard.systemMigrationTimestamp!)
          : null,
        'uploaderEmail': questCard.uploaderEmail,
        'uploadedTimestamp':
          questCard.uploadedTimestamp != null
            ? Timestamp.fromDate(questCard.uploadedTimestamp!)
            : null,
      // Keep standardizedGameSystem fields if they exist, don't overwrite on general update
      // 'standardizedGameSystem': questCard.standardizedGameSystem, // Handled separately
      // 'systemMigrationStatus': questCard.systemMigrationStatus, // Handled separately
      // 'systemMigrationTimestamp': questCard.systemMigrationTimestamp, // Handled separately
    });
  }

  Future<String?> getQuestByTitle(String title) async {
    try {
      // Perform the query and wait for the results
      var querySnapshot =
          await questCards.where("title", isEqualTo: title.toLowerCase()).get();
      String? questId;

      // Iterate through the query results to get the document ID
      for (var docSnapshot in querySnapshot.docs) {
        //log('GQT: ${docSnapshot.id}');
        questId = docSnapshot.id;
      }

      // Return the found quest ID, or null if not found
      return questId;
    } catch (e) {
      // Log any error that occurs
      log("Error completing: $e");
      return null;
    }
  }

  //delete
  Future<void> deleteQuestCard(String docId) {
    return questCards.doc(docId).delete();
  }

  // --- User related methods ---
  Stream<QuerySnapshot> getUsersStream() {
    final usersStream = users.orderBy('email', descending: true).snapshots();
    return usersStream;
  }

  Future<LocalUser?> getLocalUser(String userId) async {
    try {
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (documentSnapshot.exists) {
        return LocalUser.fromMap(
            documentSnapshot.data() as Map<String, dynamic>);
      } else {
        log("User document not found: $userId");
        return null;
      }
    } catch (e) {
      log("Error getting user document $userId: $e");
      return null;
    }
  }

  Future<List<String>?> getUserRoles(String userId) async {
    try {
      DocumentSnapshot documentSnapshot = await users.doc(userId).get();
      if (documentSnapshot.exists) {
        Map<String, dynamic> data =
            documentSnapshot.data() as Map<String, dynamic>;
        return List<String>.from(data['roles'] ?? []);
      }
    } catch (e) {
      log("Error getting user roles $userId: $e");
    }
    return null;
  }

  Future<void> storeInitialUserRole(String userId, String email) async {
    try {
      DocumentReference userDocRef = users.doc(userId);
      DocumentSnapshot documentSnapshot = await userDocRef.get();

      if (!documentSnapshot.exists) {
        await userDocRef.set({
          'roles': ['user'],
          'email': email
        });
        await emailService.sendSignupEmailToAdmin(email);
        await emailService.sendActivationEmail(email);
      }
    } catch (e) {
      log('Error storing user roles $userId: $e');
    }
  }

  getUserCardStream(String userId) {
    final userStream = users.doc(userId).snapshots();
    return userStream;
  }

  Future<void> updateUser(LocalUser user) {
    return users
        .doc(user.uid)
        .update({'uid': user.uid, 'email': user.email, 'roles': user.roles});
  }

  Future<void> deleteUser(String docId) {
    return users.doc(docId).delete();
  }

  // --- Batch operations ---
  Future<Map<String, String>> getQuestsByTitles(List<String> titles) async {
    Map<String, String> existingTitles = {};
    if (titles.isEmpty) {
      return existingTitles;
    }

    // Firestore 'whereIn' queries are limited (often to 30 items)
    List<List<String>> chunks = [];
    for (var i = 0; i < titles.length; i += 30) {
      chunks.add(
          titles.sublist(i, i + 30 > titles.length ? titles.length : i + 30));
    }

    try {
      for (var chunk in chunks) {
        if (chunk.isEmpty) continue;
        // Ensure all titles in the chunk are lowercase for the query
        var lowerCaseChunk = chunk.map((t) => t.toLowerCase()).toList();
        var querySnapshot =
            await questCards.where("title", whereIn: lowerCaseChunk).get();
        for (var docSnapshot in querySnapshot.docs) {
          var data = docSnapshot.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('title')) {
            // Ensure the title from Firestore is treated as lowercase for matching
            existingTitles[(data['title'] as String).toLowerCase()] =
                docSnapshot.id;
          }
        }
      }
    } catch (e) {
      log("Error in getQuestsByTitles: $e");
      // Depending on requirements, you might want to rethrow or handle differently
    }
    return existingTitles;
  }

  Future<List<String>> addMultipleQuestCards(
      List<QuestCard> questCardsToAdd) async {
    List<String> newDocIds = [];
    if (questCardsToAdd.isEmpty) {
      return newDocIds;
    }

    WriteBatch batch = FirebaseFirestore.instance.batch();
    int operationCount = 0;
    const int batchLimit = 500; // Firestore batch limit

    try {
      for (QuestCard questCard in questCardsToAdd) {
        DocumentReference docRef =
            questCards.doc(); // Get a new document reference
        batch.set(docRef, {
          'id': questCard
              .generateUniqueHash(), // Consider if ID should be docRef.id
          'title': questCard.title
              ?.toLowerCase(), // Ensure title is stored lowercase
          'productTitle': questCard.productTitle,
          'gameSystem': questCard.gameSystem,
          'gameSystem_lowercase':
              questCard.gameSystem?.toLowerCase(), // Add lowercase field
          'edition': questCard.edition,
          'level': questCard.level,
          'pageLength': questCard.pageLength,
          'authors': questCard.authors,
          'publisher': questCard.publisher,
          'publicationYear': questCard.publicationYear,
          'setting': questCard.setting,
          'environments': questCard.environments,
          'link': questCard.link?.toString(),
          'bossVillains': questCard.bossVillains,
          'commonMonsters': questCard.commonMonsters,
          'notableItems': questCard.notableItems,
          'summary': questCard.summary,
          'timestamp': Timestamp.now(),
          'genre': questCard.genre,
          'classification': questCard.classification,
          'uploadedBy': questCard.uploadedBy,
          'isPublic': questCard.isPublic, // Add isPublic field
        });
        newDocIds.add(docRef.id); // Store the generated ID
        operationCount++;

        // Commit batch if limit is reached and start a new one
        if (operationCount == batchLimit) {
          log('Committing batch of $operationCount operations...');
          await batch.commit();
          log('Batch committed.');
          batch = FirebaseFirestore.instance.batch(); // Start new batch
          operationCount = 0;
        }
      }

      // Commit any remaining operations in the last batch
      if (operationCount > 0) {
        log('Committing final batch of $operationCount operations...');
        await batch.commit();
        log('Final batch committed.');
      }
    } catch (e) {
      log("Error adding multiple quest cards: $e");
      // Consider how to handle partial failures if needed
      return []; // Return empty list or partial list depending on requirements
    }

    return newDocIds;
  }

  // --- Game System Standardization ---
  Future<List<QueryDocumentSnapshot>> getUnstandardizedQuestCards(
      {int limit = 50}) async {
    try {
      // Query for documents where systemMigrationStatus is null or not 'standardized'
      // and standardizedGameSystem is null.
      // Order by timestamp to process older entries first.
      Query query = questCards
          .where('systemMigrationStatus', whereIn: [
            null,
            'pending',
            'failed'
          ]) // Include null, pending, or failed
          // .where('standardizedGameSystem', isNull: true) // This might be too restrictive if some failed partially
          .orderBy('timestamp', descending: false) // Process oldest first
          .limit(limit);

      QuerySnapshot querySnapshot = await query.get();
      return querySnapshot.docs;
    } catch (e) {
      log("Error fetching unstandardized quest cards: $e");
      return [];
    }
  }

  Future<void> updateQuestCardStandardization(
      String docId, String standardizedGameSystem, String status,
      {String? originalGameSystem, String? originalEdition}) async {
    try {
      await questCards.doc(docId).update({
        'standardizedGameSystem': standardizedGameSystem,
        'systemMigrationStatus':
            status, // e.g., 'standardized', 'failed', 'manual_review'
        'systemMigrationTimestamp': Timestamp.now(),
        // Optionally store original values if needed for review
        if (originalGameSystem != null)
          'originalGameSystemForReview': originalGameSystem,
        if (originalEdition != null)
          'originalEditionForReview': originalEdition,
      });
    } catch (e) {
      log("Error updating standardization status for $docId: $e");
    }
  }

  // --- Owned Quests ---

  /// Adds a quest to a user's owned list.
  Future<void> addOwnedQuest(String userId, String questId) async {
    try {
      await users.doc(userId).collection('ownedQuests').doc(questId).set({
        'addedTimestamp': Timestamp.now(),
      });
      log('Added quest $questId to owned list for user $userId');
    } catch (e) {
      log('Error adding owned quest $questId for user $userId: $e');
      // Rethrow or handle as needed
      rethrow;
    }
  }

  /// Removes a quest from a user's owned list.
  Future<void> removeOwnedQuest(String userId, String questId) async {
    try {
      await users.doc(userId).collection('ownedQuests').doc(questId).delete();
      log('Removed quest $questId from owned list for user $userId');
    } catch (e) {
      log('Error removing owned quest $questId for user $userId: $e');
      // Rethrow or handle as needed
      rethrow;
    }
  }

  /// Checks if a user owns a specific quest. Returns a stream.
  Stream<bool> isQuestOwnedStream(String userId, String questId) {
    // Prevent errors if userId or questId is empty/invalid, return stream of false
    if (userId.isEmpty || questId.isEmpty) {
      return Stream.value(false);
    }
    return users
        .doc(userId)
        .collection('ownedQuests')
        .doc(questId)
        .snapshots()
        .map((snapshot) => snapshot.exists) // True if the document exists
        .handleError((error) {
      log('Error checking ownership for user $userId, quest $questId: $error');
      return false; // Assume not owned on error
    });
  }

  /// Fetches owned quest documents (including timestamp) for a user, with optional batching.
  /// Returns a list of document snapshots.
  Future<List<DocumentSnapshot>> getOwnedQuestsBatch(String userId,
      {DocumentSnapshot? startAfter, int limit = 20}) async {
    try {
      Query query = users
          .doc(userId)
          .collection('ownedQuests')
          .orderBy('addedTimestamp', descending: true) // Example sort
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs;
    } catch (e) {
      log('Error fetching owned quests batch for user $userId: $e');
      return [];
    }
  }

  /// Fetches the full QuestCard data for a list of owned quest IDs.
  /// Handles Firestore's 'whereIn' limit of 30 IDs per query.
  Future<List<QuestCard>> getQuestCardsByIds(List<String> questIds) async {
    if (questIds.isEmpty) {
      return [];
    }

    List<QuestCard> results = [];
    List<List<String>> chunks = [];
    const int limit = 30;

    for (int i = 0; i < questIds.length; i += limit) {
      chunks.add(questIds.sublist(
          i, i + limit > questIds.length ? questIds.length : i + limit));
    }

    try {
      for (List<String> chunk in chunks) {
        if (chunk.isEmpty) continue;
        final querySnapshot =
            await questCards.where(FieldPath.documentId, whereIn: chunk).get();
        for (var doc in querySnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              // Use fromJson and set objectId manually
              final questCard = QuestCard.fromJson(data);
              questCard.objectId = doc.id; // Set the Firestore document ID
              results.add(questCard);
            }
          } catch (e) {
            log("Error parsing QuestCard from Firestore doc ${doc.id}: $e");
            // Optionally skip this card or handle error differently
          }
        }
      }
    } catch (e) {
      log("Error fetching quest cards by IDs: $e");
      // Depending on requirements, might want to return partial results or rethrow
    }

    // Sort results by title after fetching all chunks
    try {
      results.sort((a, b) {
        var titleA = a.title?.toLowerCase() ?? '';
        var titleB = b.title?.toLowerCase() ?? '';
        return titleA.compareTo(titleB);
      });
    } catch (e) {
      log("Error sorting final results by title: $e");
    }

    return results;
  }
} // End of FirestoreService class

// Helper extension for cloning FilterState (if not already present)
// Make sure this extension is defined only once in your project.
// If it's already defined elsewhere (e.g., in filter_state.dart), remove it from here.
extension FilterStateClone on FilterState {
  FilterState clone() {
    final newState = FilterState();
    for (var filter in filters) {
      // Assuming FilterCriteria constructor creates a deep enough copy
      // or FilterCriteria is immutable. If value can be a mutable object,
      // a deeper copy might be needed here.
      newState.addFilter(FilterCriteria(
          field: filter.field, value: filter.value, operator: filter.operator));
    }
    return newState;
  }
}
