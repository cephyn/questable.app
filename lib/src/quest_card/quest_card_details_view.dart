import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'quest_card.dart';

/// Displays detailed information about a SampleItem.
class QuestCardDetailsView extends StatelessWidget {
  const QuestCardDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    QuestCard questCard = QuestCard();
    final FirestoreService firestoreService = FirestoreService();

    if (ModalRoute.of(context)?.settings.arguments != null) {
      final Map<String, dynamic> args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      if (args['docId'] != null) {
        return StreamBuilder<DocumentSnapshot>(
            stream: firestoreService.getQuestCardStream(args['docId']),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                Map<String, dynamic> data =
                    snapshot.data!.data() as Map<String, dynamic>;
                questCard = QuestCard.fromJson(data);
              } else {
                return const CircularProgressIndicator();
              }
              return Scaffold(
                appBar: AppBar(
                  title: Text('Quest Card Details'),
                ),
                body: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        children: [
                          Text('Title: ${questCard.title ?? 'N/A'}',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          Text('Game System: ${questCard.gameSystem ?? 'N/A'}'),
                          Text('Edition: ${questCard.edition ?? 'N/A'}'),
                          Text('Level: ${questCard.level ?? 'N/A'}'),
                          Text('Page Length: ${questCard.pageLength ?? 'N/A'}'),
                          Text(
                              'Authors: ${questCard.authors?.join(', ') ?? 'N/A'}'),
                          Text('Publisher: ${questCard.publisher ?? 'N/A'}'),
                          Text(
                              'Publication Year: ${questCard.publicationYear ?? 'N/A'}'),
                          Text('Genre: ${questCard.genre ?? 'N/A'}'),
                          Text('Setting: ${questCard.setting ?? 'N/A'}'),
                          Text(
                              'Environments: ${questCard.environments?.join(', ') ?? 'N/A'}'),
                          Text('Link: ${questCard.link ?? 'N/A'}'),
                          Text(
                              'Boss Villains: ${questCard.bossVillains?.join(', ') ?? 'N/A'}'),
                          Text(
                              'Common Monsters: ${questCard.commonMonsters?.join(', ') ?? 'N/A'}'),
                          Text(
                              'Notable Items: ${questCard.notableItems?.join(', ') ?? 'N/A'}'),
                          Text('Summary: ${questCard.summary ?? 'N/A'}'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            });
      } else {
        return Scaffold(body: Placeholder());
      }
    } else {
      return Scaffold(body: Placeholder());
    }
  }
}
