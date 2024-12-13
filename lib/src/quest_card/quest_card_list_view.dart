import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/quest_card/quest_card_details_view.dart';
import 'package:quest_cards/src/quest_card/quest_card_edit.dart';
import 'package:quest_cards/src/role_based_widgets/role_based_delete_documents_button.dart';
import 'package:quest_cards/src/services/firebase_auth_service.dart';
import 'package:quest_cards/src/services/firestore_service.dart';

class QuestCardListView extends StatelessWidget {
  QuestCardListView({super.key});
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();
  final RoleBasedDeleteDocumentsButton rbDeleteDocumentsButton =
      RoleBasedDeleteDocumentsButton();

  @override
  Widget build(BuildContext context) {
    //firestoreService.storeInitialUserRole(
    //auth.getCurrentUser().uid, auth.getCurrentUser().email!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
      ),
      body: Center(
        child: StreamBuilder<QuerySnapshot>(
          stream: firestoreService.getQuestCardsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              List<QueryDocumentSnapshot> queryCardList = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: queryCardList.length,
                itemBuilder: (context, index) {
                  DocumentSnapshot document = queryCardList[index];
                  String docId = document.id;
                  Map<String, dynamic> data =
                      document.data() as Map<String, dynamic>;
                  String title = data['title'];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            AssetImage('assets/images/QuestableTx4x4.png'),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QuestCardDetailsView(),
                            settings:
                                RouteSettings(arguments: {'docId': docId}),
                          ),
                        );
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditQuestCard(
                                    docId: docId,
                                  ),
                                ),
                              );
                            },
                          ),
                          rbDeleteDocumentsButton.deleteQuestCardButton(
                              auth.getCurrentUser().uid, docId),
                        ],
                      ),
                    ),
                  );
                },
              );
            } else {
              return const Text("No Quests");
            }
          },
        ),
      ),
    );
  }
}
