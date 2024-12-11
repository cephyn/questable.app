import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/quest_card/quest_card_edit.dart';
import 'package:quest_cards/src/quest_card/quest_card_details_view.dart';
import 'package:quest_cards/src/role_based_widgets/role_based_delete_documents_button.dart';
import 'package:quest_cards/src/services/firebase_auth_service.dart';
import 'package:quest_cards/src/services/firestore_service.dart';

import '../user/local_user.dart';

class QuestCardListView extends StatelessWidget {
  QuestCardListView({super.key});
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();
  final RoleBasedDeleteDocumentsButton rbDeleteDocumentsButton =
      RoleBasedDeleteDocumentsButton();

  @override
  Widget build(BuildContext context) {
    firestoreService.storeInitialUserRole(auth.getCurrentUser().uid);

    return Scaffold(
      // To work with lists that may contain a large number of items, it’s best
      // to use the ListView.builder constructor.
      //
      // In contrast to the default ListView constructor, which requires
      // building all Widgets up front, the ListView.builder constructor lazily
      // builds Widgets as they’re scrolled into view.
      body: Center(
        child: StreamBuilder<QuerySnapshot>(
          stream: firestoreService.getQuestCardsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              List queryCardList = snapshot.data!.docs;
              //display as list
              return ListView.builder(
                itemCount: queryCardList.length,
                itemBuilder: (context, index) {
                  //get each doc
                  DocumentSnapshot document = queryCardList[index];
                  String docId = document.id;
                  //get title from each doc
                  Map<String, dynamic> data =
                      document.data() as Map<String, dynamic>;
                  String title = data['title'];
                  //display as a list tile
                  return ListTile(
                    leading: const CircleAvatar(
                      // Display the Flutter Logo image asset.
                      foregroundImage:
                          AssetImage('assets/images/flutter_logo.png'),
                    ),
                    title: Text(title),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuestCardDetailsView(),
                          settings: RouteSettings(arguments: {'docId': docId}),
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
                            }),
                        rbDeleteDocumentsButton.deleteQuestCardButton(
                            auth.getCurrentUser().uid, docId),
                      ],
                    ),
                  );
                },
              );
            } else {
              return const Text("No QuestCards");
            }
          },
        ),
      ),
    );
  }
}
