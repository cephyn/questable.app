import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
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
      'title': questCard.title!.toLowerCase(),
      'productTitle': questCard.productTitle,
      'gameSystem': questCard.gameSystem,
      'edition': questCard.edition,
      'level': questCard.level,
      'pageLength': questCard.pageLength,
      'authors': questCard.authors,
      'publisher': questCard.publisher,
      'publicationYear': questCard.publicationYear,
      'setting': questCard.setting,
      'environments': questCard.environments,
      'link': questCard.link.toString(),
      'bossVillains': questCard.bossVillains,
      'commonMonsters': questCard.commonMonsters,
      'notableItems': questCard.notableItems,
      'summary': questCard.summary,
      'timestamp': Timestamp.now(),
      'genre': questCard.genre,
      'classification': questCard.classification,
      'uploadedBy': questCard.uploadedBy,
    }).then((DocumentReference ref) {
      docId = ref.id;
    });
    //print(docId);
    return docId;
  }

  //read
  /// Gets a stream of quest cards matching the given document IDs.
  /// If docIds is empty, returns all cards sorted by title.
  /// If docIds contains more than 30 IDs (Firestore's 'whereIn' limit),
  /// the function breaks the list into chunks and combines the results.
  Stream<List<QueryDocumentSnapshot<Object?>>> getQuestCardsStream(
      List<String> docIds) {
    if (docIds.isEmpty) {
      // Return all cards if no specific IDs are provided
      return questCards
          .orderBy('title', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs);
    }

    // Firestore 'whereIn' query limit
    const int limit = 30;

    if (docIds.length <= limit) {
      // If the list is within the limit, use a single query
      return questCards
          .where(FieldPath.documentId, whereIn: docIds)
          .snapshots()
          .map((snapshot) => snapshot.docs);
    } else {
      // If the list exceeds the limit, break it into chunks
      List<Stream<List<QueryDocumentSnapshot>>> streams = [];

      for (int i = 0; i < docIds.length; i += limit) {
        List<String> chunk = docIds.sublist(
            i, i + limit > docIds.length ? docIds.length : i + limit);

        if (chunk.isNotEmpty) {
          streams.add(questCards
              .where(FieldPath.documentId, whereIn: chunk)
              .snapshots()
              .map((snapshot) => snapshot.docs));
        }
      }

      // Use MergeStream to emit as soon as any source emits, but
      // buffer and deduplicate with distinct() based on doc IDs
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

  Future<int> getQuestCardsCount() async {
    try {
      var res = await questCards.count().get();
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
      'title': questCard.title!.toLowerCase(),
      'productTitle': questCard.productTitle,
      'gameSystem': questCard.gameSystem,
      'edition': questCard.edition,
      'level': questCard.level,
      'pageLength': questCard.pageLength,
      'authors': questCard.authors,
      'publisher': questCard.publisher,
      'publicationYear': questCard.publicationYear,
      'setting': questCard.setting,
      'environments': questCard.environments,
      'link': questCard.link.toString(),
      'bossVillains': questCard.bossVillains,
      'commonMonsters': questCard.commonMonsters,
      'notableItems': questCard.notableItems,
      'summary': questCard.summary,
      'timestamp': Timestamp.now(),
      'genre': questCard.genre,
      'classification': questCard.classification,
      'uploadedBy': questCard.uploadedBy,
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
}
