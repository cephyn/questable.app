import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/quest_card/quest_card_details_view.dart';
import 'package:quest_cards/src/quest_card/quest_card_edit.dart';
import 'package:quest_cards/src/role_based_widgets/role_based_delete_documents_buttons.dart';
import 'package:quest_cards/src/services/firebase_auth_service.dart';
import 'package:quest_cards/src/services/firestore_service.dart';

import '../util/utils.dart';

class QuestCardListView extends StatelessWidget {
  QuestCardListView({super.key});
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();
  final RoleBasedDeleteDocumentsButtons rbDeleteDocumentsButtons =
      RoleBasedDeleteDocumentsButtons();

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle("List Quests");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10.0),
          child: FutureBuilder<int>(
            future: firestoreService.getQuestCardsCount(),
            builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                );
              } else if (snapshot.hasData) {
                int count = snapshot.data!;
                return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "$count Quests Scribed",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ));
              } else {
                return Text(
                  'No data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
            },
          ),
        ),
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
                            Utils.getSystemIcon(data['gameSystem']),
                      ),
                      title: AutoSizeText(
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
                          rbDeleteDocumentsButtons.deleteQuestCardButton(
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
