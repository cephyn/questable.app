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

  //create
  Future<String> addQuestCard(QuestCard questCard) async {
    String docId = "";
    await questCards.add({
      'id': questCard.generateUniqueHash(),
      'title':
          questCard.title?.toLowerCase(), // Ensure title is stored lowercase
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
    }).then((DocumentReference ref) {
      docId = ref.id;
    });
    //print(docId);
    return docId;
  }

  //read
  /// Gets a stream of quest cards matching the given document IDs.
  /// If docIds is empty, returns all cards sorted by title.
  /// @param filterState Optional filter state to apply filtering
  Stream<List<QueryDocumentSnapshot<Object?>>> getQuestCardsStream(
      List<String> docIds,
      {FilterState? filterState}) {
    Query baseQuery;

    if (docIds.isEmpty) {
      // Return all cards if no specific IDs are provided
      baseQuery = questCards.orderBy('title', descending: true);
    } else {
      // Firestore 'whereIn' query limit
      const int limit = 30;

      if (docIds.length <= limit) {
        // If the list is within the limit, use a single query
        baseQuery = questCards.where(FieldPath.documentId, whereIn: docIds);
      } else {
        // If the list exceeds the limit, break it into chunks
        List<Stream<List<QueryDocumentSnapshot>>> streams = [];
        for (int i = 0; i < docIds.length; i += limit) {
          List<String> chunk = docIds.sublist(
              i, i + limit > docIds.length ? docIds.length : i + limit);

          if (chunk.isNotEmpty) {
            Query chunkQuery =
                questCards.where(FieldPath.documentId, whereIn: chunk);
            // Apply filters to each chunk query if provided
            if (filterState != null && filterState.hasFilters) {
              chunkQuery = filterState.applyFiltersToQuery(chunkQuery);
            }

            streams
                .add(chunkQuery.snapshots().map((snapshot) => snapshot.docs));
          }
        }

        // Use Rx.combineLatest to combine the chunks
        return Rx.combineLatest<List<QueryDocumentSnapshot<Object?>>,
            List<QueryDocumentSnapshot<Object?>>>(streams, (listOfDocLists) {
          // Flatten list of lists into a single list
          final combinedDocs = listOfDocLists.expand((list) => list).toList();

          // Remove duplicates (in case a document appears in multiple chunks)
          final uniqueDocs = <String, QueryDocumentSnapshot<Object?>>{};
          for (final doc in combinedDocs) {
            uniqueDocs[doc.id] = doc;
          }

          return uniqueDocs.values.toList();
        });
      }
    }

    // Apply filters if provided
    if (filterState != null && filterState.hasFilters) {
      baseQuery = filterState.applyFiltersToQuery(baseQuery);
    }

    return baseQuery.snapshots().map((snapshot) => snapshot.docs);
  }

  /// Gets a stream of all quest cards for public access without requiring authentication.
  /// Returns all cards sorted by title.
  /// @param filterState Optional filter state to apply filtering
  Stream<List<QueryDocumentSnapshot<Object?>>> getPublicQuestCardsStream(
      {FilterState? filterState}) {
    // Start with base query
    Query query = questCards.orderBy('title');

    // Apply filters if provided
    if (filterState != null && filterState.hasFilters) {
      query = filterState.applyFiltersToQuery(query);
    }

    return query.snapshots().map((snapshot) => snapshot.docs);
  }

  /// Gets the count of all quest cards for public access without requiring authentication.
  /// @param filterState Optional filter state to apply filtering when counting
  Future<int> getPublicQuestCardCount({FilterState? filterState}) async {
    try {
      // Start with base query
      Query query = questCards;

      // Apply filters if provided
      if (filterState != null && filterState.hasFilters) {
        query = filterState.applyFiltersToQuery(query);
      }

      var res = await query.count().get();
      return res.count!;
    } catch (e) {
      log("Error getting public quest card count: $e");
      return 0;
    }
  }

  Future<int> getQuestCardsCount({FilterState? filterState}) async {
    try {
      // Start with base query
      Query query = questCards;

      // Apply filters if provided
      if (filterState != null && filterState.hasFilters) {
        query = filterState.applyFiltersToQuery(query);
      }

      var res = await query.count().get();
      return res.count!;
    } catch (e) {
      log("Error completing: $e");
      return 0; // or any appropriate default value
    }
  }

  Stream<DocumentSnapshot> getQuestCardStream(String docId) {
    final questCardStream = questCards.doc(docId).snapshots();
    return questCardStream;
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

  // Batch check for existing titles
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
        var querySnapshot =
            await questCards.where("title", whereIn: chunk).get();
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

  // Batch add multiple quest cards
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
      log("Error in addMultipleQuestCards during batch commit: $e");
      // Handle batch error - potentially some cards were added, some not.
      // Consider adding retry logic or more robust error handling.
      rethrow; // Rethrow for higher level handling
    }

    return newDocIds;
  }

  /// Gets a batch of quest cards for pagination in the public view
  /// @param limit The maximum number of documents to fetch
  /// @param lastDocument The last document from the previous batch (for pagination)
  /// @param filterState Optional filter state to apply filtering
  Future<List<QueryDocumentSnapshot>> getPublicQuestCardsBatch(
      int limit, DocumentSnapshot? lastDocument,
      {FilterState? filterState}) async {
    try {
      // Start with base query
      Query query = questCards.orderBy('title').limit(limit);

      // If we have a last document, start after it for pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      // Apply filters if provided
      if (filterState != null && filterState.hasFilters) {
        query = filterState.applyFiltersToQuery(query);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs;
    } catch (e) {
      log("Error getting quest card batch: $e");
      return [];
    }
  }

  /// Get a quest card by its document ID
  /// @param docId The Firestore document ID
  /// @return A Map containing the quest card data, or null if not found
  Future<Map<String, dynamic>?> getQuestCardById(String docId) async {
    try {
      DocumentSnapshot documentSnapshot = await questCards.doc(docId).get();
      if (documentSnapshot.exists) {
        return documentSnapshot.data() as Map<String, dynamic>;
      } else {
        log("Quest card not found: $docId");
        return null;
      }
    } catch (e) {
      log("Error getting quest card: $e");
      throw Exception("Failed to load quest card: $e");
    }
  }

  /// Gets the distinct values for a specific field to populate filter options
  /// @param field The field to get distinct values for
  /// @param limit Optional limit on the number of distinct values to return
  Future<List<dynamic>> getDistinctFieldValues(String field,
      {int limit = 100}) async {
    try {
      // This query gets documents with distinct values for the specified field
      final query = questCards.limit(limit);
      final snapshot = await query.get();

      // Set to track all unique values
      final values = <dynamic>{};

      // Extract the field values and remove duplicates
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey(field) && data[field] != null) {
          final fieldValue = data[field];

          // Handle array fields (like 'environments')
          if (fieldValue is List) {
            // Add each item in the array to our set of values
            for (var item in fieldValue) {
              if (item != null && item.toString().isNotEmpty) {
                values.add(item);
              }
            }
          } else {
            // Handle scalar values
            if (fieldValue.toString().isNotEmpty) {
              values.add(fieldValue);
            }
          }
        }
      }

      // Convert the set to a list
      final result = values.toList();

      // Sort if possible (all elements must be comparable)
      try {
        result.sort();
      } catch (e) {
        log("Warning: Could not sort values for field $field: $e");
      }

      return result;
    } catch (e) {
      log("Error getting distinct values for $field: $e");
      return [];
    }
  }

  /// Updates all existing quest cards to add the isPublic field if it's missing
  /// This is a migration function to ensure all documents have the required field
  Future<void> migrateQuestCardsAddIsPublic() async {
    try {
      log('Starting migration: Adding isPublic field to all quest cards...');

      // Get all quest cards without pagination
      final QuerySnapshot snapshot = await questCards.get();
      int totalDocs = snapshot.size;
      int updatedDocs = 0;
      int skippedDocs = 0;

      log('Found $totalDocs quest cards to check');

      // Create a batch for updates
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int batchCount = 0;
      const int batchLimit = 500; // Firestore batch limit

      // Process each document
      for (QueryDocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Only update documents that don't already have the field
        if (!data.containsKey('isPublic')) {
          batch.update(doc.reference, {
            'isPublic': true // Set default value to true
          });
          batchCount++;
          updatedDocs++;

          // Commit batch if limit reached
          if (batchCount >= batchLimit) {
            await batch.commit();
            log('Committed batch of $batchCount updates');
            batch = FirebaseFirestore.instance.batch();
            batchCount = 0;
          }
        } else {
          skippedDocs++;
        }
      }

      // Commit any remaining operations
      if (batchCount > 0) {
        await batch.commit();
        log('Committed final batch of $batchCount updates');
      }

      log('Migration completed: $updatedDocs documents updated, $skippedDocs already had the field');
    } catch (e) {
      log('Error during migration: $e');
      throw Exception('Failed to migrate quest cards: $e');
    }
  }

  /// Checks if any quest cards are missing the isPublic field
  /// Returns the count of documents missing the field
  Future<int> checkMissingIsPublicField() async {
    try {
      log('Checking for documents missing isPublic field...');

      final QuerySnapshot snapshot = await questCards.get();
      int totalDocs = snapshot.size;
      int missingField = 0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('isPublic')) {
          missingField++;
          log('Document ${doc.id} is missing isPublic field');
        }
      }

      log('Found $missingField/$totalDocs documents missing the isPublic field');
      return missingField;
    } catch (e) {
      log("Error checking for missing isPublic field: $e");
      return -1; // Return -1 to indicate an error occurred
    }
  }
}
