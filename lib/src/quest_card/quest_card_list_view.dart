import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:quest_cards/src/quest_card/quest_card.dart';
import 'package:quest_cards/src/quest_card/quest_card_details_view.dart';

import '../settings/settings_view.dart';

class QuestCardListView extends StatelessWidget {

  const QuestCardListView({super.key});

  @override
  Widget build(BuildContext context) {
    //TESTING
    String mockQuestJson = QuestCard.getMockJsonData();
    //print(mockQuestJson);
    List<QuestCard> myCards = [];

    var quests = jsonDecode(mockQuestJson)['quests'];
    for(int i=0; i<quests.length; i++){
      QuestCard qc = QuestCard.fromJson(quests[i]);
      myCards.add(qc);
    }

    //QuestCard qc = QuestCard.fromJson(jsonDecode(mockQuestJson));
    //print(qc);
    //List<QuestCard> myCards =[qc];

    return Scaffold(
      

      // To work with lists that may contain a large number of items, it’s best
      // to use the ListView.builder constructor.
      //
      // In contrast to the default ListView constructor, which requires
      // building all Widgets up front, the ListView.builder constructor lazily
      // builds Widgets as they’re scrolled into view.
      body: Center(
        
        child: ListView.builder(
          
          // Providing a restorationId allows the ListView to restore the
          // scroll position when a user leaves and returns to the app after it
          // has been killed while running in the background.
          restorationId: 'questCardListView',
          itemCount: myCards.length,
          itemBuilder: (BuildContext context, int index) {
            final item = myCards[index];
        
            return ListTile(
                title: Text('${item.title}'),
                leading: const CircleAvatar(
                  // Display the Flutter Logo image asset.
                  foregroundImage: AssetImage('assets/images/flutter_logo.png'),
                ),
                onTap: () {
                  // Navigate to the details page. If the user leaves and returns to
                  // the app after it has been killed while running in the
                  // background, the navigation stack is restored.
                  /*
                  Navigator.restorablePushNamed(
                    context,
                    QuestCardListView.routeName,
                  );*/
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuestCardDetailsView(),
                      settings: RouteSettings(arguments: item.id),
                    ),
                  );
                });
          },
        ),
      ),
    );
  }
}
