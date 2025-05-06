import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<QuerySnapshot> getSubmittedQuestsStream() {
    if (currentUser == null) {
      return Stream.empty();
    }
    return _firestore
        .collection('questCards')
        .where('uploadedBy', isEqualTo: currentUser!.uid)
        .orderBy('title')
        .snapshots();
  }

  Future<List<DocumentSnapshot>> getOwnedQuests() async {
    if (currentUser == null) {
      return [];
    }
    try {
      final ownedRefs = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('ownedQuests')
          .get();

      final ownedIds = ownedRefs.docs.map((doc) => doc.id).toList();

      if (ownedIds.isEmpty) {
        return [];
      }

      List<DocumentSnapshot> ownedQuests = [];
      const int batchSize = 30;
      for (var i = 0; i < ownedIds.length; i += batchSize) {
        final sublist = ownedIds.sublist(i,
            i + batchSize > ownedIds.length ? ownedIds.length : i + batchSize);
        if (sublist.isNotEmpty) {
          final questSnapshots = await _firestore
              .collection('questCards')
              .where(FieldPath.documentId, whereIn: sublist)
              .get();
          ownedQuests.addAll(questSnapshots.docs);
        }
      }
      return ownedQuests;
    } catch (e) {
      log('Error fetching owned quests: $e');
      return [];
    }
  }

  Future<void> addQuestToOwned(String questId) async {
    if (currentUser == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('ownedQuests')
          .doc(questId)
          .set({'ownedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      log('Error adding quest to owned: $e');
    }
  }

  Future<void> removeQuestFromOwned(String questId) async {
    if (currentUser == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('ownedQuests')
          .doc(questId)
          .delete();
    } catch (e) {
      log('Error removing quest from owned: $e');
    }
  }

  Stream<DocumentSnapshot> getOwnershipStream(String questId) {
    if (currentUser == null) {
      return Stream.empty(); // Return an empty stream if user is not logged in
    }
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('ownedQuests')
        .doc(questId)
        .snapshots();
  }
}
