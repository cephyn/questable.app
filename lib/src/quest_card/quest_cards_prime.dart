import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:quest_cards/src/app.dart';

import '../services/firestore_service.dart';
import 'quest_card.dart';

class PrimeQuestCards extends StatelessWidget {
  PrimeQuestCards({super.key});
  final FirestoreService firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ElevatedButton(
          onPressed: () {
            String mockQuestJson = QuestCard.getMockJsonData();
            //print(mockQuestJson);
            List<QuestCard> myCards = [];

            var quests = jsonDecode(mockQuestJson)['quests'];
            for (int i = 0; i < quests.length; i++) {
              QuestCard qc = QuestCard.fromJson(quests[i]);
              myCards.add(qc);
            }
            for (QuestCard mc in myCards) {
              firestoreService.addQuestCard(mc);
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePage(),
              ),
            );
          },
          child: const Text('Submit'),
        ),
      ),
    );
  }
}
