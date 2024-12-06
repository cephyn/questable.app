import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/app.dart';
import 'package:quest_cards/src/services/firestore_service.dart';

import 'quest_card.dart';

class EditQuestCard extends StatefulWidget {
  const EditQuestCard({super.key});

  @override
  State<EditQuestCard> createState() {
    return _AddQuestCardState();
  }
}

class _AddQuestCardState extends State<EditQuestCard> {
  final _formKey = GlobalKey<FormState>();
  QuestCard _questCard = QuestCard();
  final FirestoreService firestoreService = FirestoreService();
  

  @override
  Widget build(BuildContext context) {
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
                _questCard = QuestCard.fromJson(data);
              } else {
                return const CircularProgressIndicator();
              }
              return Scaffold(body: getQuestCardForm(context, args['docId']));
            });
      }
      else{
        return Scaffold(body: getQuestCardForm(context, null));
      }
    } else {
      return Scaffold(body: getQuestCardForm(context, null));
    }
  }

  Form getQuestCardForm(BuildContext context, String? docId) {
    return Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            TextFormField(
              decoration: InputDecoration(labelText: 'Title'),
              initialValue: _questCard.title,
              onSaved: (value) => _questCard.title = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Game System'),
              initialValue: _questCard.gameSystem,
              onSaved: (value) => _questCard.gameSystem = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Edition'),
              initialValue: _questCard.edition,
              onSaved: (value) => _questCard.edition = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Level'),
              initialValue: _questCard.level,
              onSaved: (value) => _questCard.level = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Page Length'),
              initialValue: _questCard.pageLength?.toString(),
              keyboardType: TextInputType.number,
              onSaved: (value) =>
                  _questCard.pageLength = int.tryParse(value ?? ''),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Authors'),
              initialValue: _questCard.authors?.join(", "),
              onSaved: (value) => _questCard.authors = value?.split(','),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Publisher'),
              initialValue: _questCard.publisher,
              onSaved: (value) => _questCard.publisher = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Publication Year'),
              initialValue: _questCard.publicationYear,
              onSaved: (value) => _questCard.publicationYear = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Setting'),
              initialValue: _questCard.setting,
              onSaved: (value) => _questCard.setting = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Environments'),
              initialValue: _questCard.environments?.join(", "),
              onSaved: (value) => _questCard.environments = value?.split(','),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Link'),
              initialValue: _questCard.link,
              onSaved: (value) => _questCard.link = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Boss Villains'),
              initialValue: _questCard.bossVillains?.join(", "),
              onSaved: (value) => _questCard.bossVillains = value?.split(','),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Common Monsters'),
              initialValue: _questCard.commonMonsters?.join(", "),
              onSaved: (value) => _questCard.commonMonsters = value?.split(','),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Notable Items'),
              initialValue: _questCard.notableItems?.join(", "),
              onSaved: (value) => _questCard.notableItems = value?.split(','),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Summary'),
              initialValue: _questCard.summary,
              onSaved: (value) => _questCard.summary = value,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton(
                onPressed: () {
                  // Validate returns true if the form is valid, or false otherwise.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState?.save();
                    if(docId == null){
                      firestoreService.addQuestCard(_questCard);
                    }
                    else{
                      firestoreService.updateQuestCard(docId, _questCard);
                    }
                    // If the form is valid, display a snackbar. In the real world,
                    // you'd often call a server or save the information in a database.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(),
                      ),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ),
          ],
        ));
  }
}
