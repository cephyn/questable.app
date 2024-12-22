import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quest_cards/src/services/email_service.dart';

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
  Stream<QuerySnapshot> getQuestCardsStream() {
    final questCardsStream =
        questCards.orderBy('title', descending: true).snapshots();
    return questCardsStream;
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
    return questCards.doc(docId).update({
      'id': questCard.generateUniqueHash(),
      'title': questCard.title!.toLowerCase(),
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
}
