
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/app.dart';
import 'package:quest_cards/src/services/firestore_service.dart';

import '../settings/settings_controller.dart';
import 'quest_card.dart';

class EditQuestCard extends StatefulWidget {
  final String docId;
  const EditQuestCard({super.key, required this.docId});

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
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.docId != '') {
      return StreamBuilder<DocumentSnapshot>(
          stream: firestoreService.getQuestCardStream(widget.docId),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              Map<String, dynamic> data =
                  snapshot.data!.data() as Map<String, dynamic>;
              _questCard = QuestCard.fromJson(data);
            } else {
              return const CircularProgressIndicator();
            }
            return Scaffold(
                appBar: AppBar(
                  title: Text('Edit Quest Card'),
                ),
                body: getQuestCardForm(context, widget.docId));
          });
    } else {
      return Scaffold(body: getQuestCardForm(context, null));
    }
  }

  Form getQuestCardForm(BuildContext context, String? docId) {
    final settingsController = Provider.of<SettingsController>(context);
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            _buildTextField(
              label: 'Title',
              initialValue: _questCard.title,
              onSaved: (value) => _questCard.title = value,
            ),
            _buildTextField(
              label: 'Game System',
              initialValue: _questCard.gameSystem,
              onSaved: (value) => _questCard.gameSystem = value,
            ),
            _buildTextField(
              label: 'Edition',
              initialValue: _questCard.edition,
              onSaved: (value) => _questCard.edition = value,
            ),
            _buildTextField(
              label: 'Level',
              initialValue: _questCard.level,
              onSaved: (value) => _questCard.level = value,
            ),
            _buildTextField(
              label: 'Page Length',
              initialValue: _questCard.pageLength?.toString(),
              keyboardType: TextInputType.number,
              onSaved: (value) =>
                  _questCard.pageLength = int.tryParse(value ?? ''),
            ),
            _buildTextField(
              label: 'Authors',
              initialValue: _questCard.authors?.join(", "),
              onSaved: (value) => _questCard.authors = value?.split(','),
            ),
            _buildTextField(
              label: 'Publisher',
              initialValue: _questCard.publisher,
              onSaved: (value) => _questCard.publisher = value,
            ),
            _buildTextField(
              label: 'Publication Year',
              initialValue: _questCard.publicationYear,
              onSaved: (value) => _questCard.publicationYear = value,
            ),
            _buildTextField(
              label: 'Genre',
              initialValue: _questCard.genre,
              onSaved: (value) => _questCard.genre = value,
            ),
            _buildTextField(
              label: 'Setting',
              initialValue: _questCard.setting,
              onSaved: (value) => _questCard.setting = value,
            ),
            _buildTextField(
              label: 'Environments',
              initialValue: _questCard.environments?.join(", "),
              onSaved: (value) => _questCard.environments = value?.split(','),
            ),
            _buildTextField(
              label: 'Product Link',
              initialValue: _questCard.link,
              onSaved: (value) => _questCard.link = value,
            ),
            _buildTextField(
              label: 'Boss Villains',
              initialValue: _questCard.bossVillains?.join(", "),
              onSaved: (value) => _questCard.bossVillains = value?.split(','),
            ),
            _buildTextField(
              label: 'Common Monsters',
              initialValue: _questCard.commonMonsters?.join(", "),
              onSaved: (value) => _questCard.commonMonsters = value?.split(','),
            ),
            _buildTextField(
              label: 'Notable Items',
              initialValue: _questCard.notableItems?.join(", "),
              maxLines: null,
              onSaved: (value) => _questCard.notableItems = value?.split(','),
            ),
            _buildTextField(
              label: 'Summary',
              initialValue: _questCard.summary,
              maxLines: null,
              onSaved: (value) => _questCard.summary = value,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState?.save();
                    if (docId == null) {
                      firestoreService.addQuestCard(_questCard);
                    } else {
                      firestoreService.updateQuestCard(docId, _questCard);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            HomePage(settingsController: settingsController),
                      ),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    int? maxLines = 1,
    required FormFieldSetter<String?> onSaved,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        initialValue: initialValue,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onSaved: onSaved,
      ),
    );
  }
}
