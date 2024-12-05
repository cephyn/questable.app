import 'package:flutter/material.dart';

import 'quest_card.dart';

/// Displays detailed information about a SampleItem.
class QuestCardDetailsView extends StatelessWidget {
  const QuestCardDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final questCard = ModalRoute.of(context)!.settings.arguments;


    return Scaffold(
      appBar: AppBar(
        title: Text(questCard.toString()),
      ),
      body: Center(
        child: Text(questCard.toString()),
      ),
    );
  }
}