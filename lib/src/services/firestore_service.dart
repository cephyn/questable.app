import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../quest_card/quest_card.dart';

class FirestoreService {
  //get collection of quest cards
  final CollectionReference questCards =
      FirebaseFirestore.instance.collection('questCards');

  //create
  Future<String> addQuestCard(QuestCard questCard) async {
    String docId = "";
    await questCards.add({
      'id': questCard.generateUniqueHash(),
      'title': questCard.title,
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
    final questCardsStream = questCards.doc(docId).snapshots();
    return questCardsStream;
  }

  //update
  Future<void> updateQuestCard(String docId, QuestCard questCard) {
    return questCards.doc(docId).update({
      'id': questCard.generateUniqueHash(),
      'title': questCard.title,
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
    });
  }

  //delete
  Future<void> deleteQuestCard(String docId) {
    return questCards.doc(docId).delete();
  }
}
