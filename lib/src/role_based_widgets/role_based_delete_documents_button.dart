import 'package:flutter/material.dart';
import 'package:quest_cards/src/services/firestore_service.dart';

class RoleBasedDeleteDocumentsButton {
  final FirestoreService firestoreService = FirestoreService();

  FutureBuilder<List<String>?> deleteQuestCardButton(
      String userId, String docId) {
    return FutureBuilder<List<String>?>(
      future: firestoreService.getUserRoles(userId),
      builder: (BuildContext context, AsyncSnapshot<List<String>?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData) {
          List<String>? roles = snapshot.data;
          if (roles != null && roles.contains('admin')) {
            return IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                firestoreService.deleteQuestCard(docId);
              },
            );
          } else {
            return Container(); // Or any other widget for non-admin users
          }
        } else {
          return Text('No roles found');
        }
      },
    );
  }
}
