import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/services/firestore_service.dart';

import '../util/utils.dart';
import 'quest_card.dart';
import 'quest_card_details_view.dart';

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
  late QuestCard
      _questCard; // Changed from nullable to non-nullable with late initialization
  bool _isLoading = true;
  final FirestoreService firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Initialize with an empty quest card to avoid null issues
    _questCard = QuestCard();

    // Load data from Firestore if editing an existing card
    if (widget.docId.isNotEmpty) {
      _loadQuestCardData();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Separate method to load quest card data
  void _loadQuestCardData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('questCards')
          .doc(widget.docId)
          .get();

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _questCard = QuestCard.fromJson(data);
          _questCard.id = data['id']; // Ensure ID is preserved
          _isLoading = false;
          log('Loaded quest card: ${_questCard.toJson()}');
        });
      } else {
        log('Document does not exist: ${widget.docId}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Error loading quest card: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle("Edit Quest");

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Quest Card'),
      ),
      body: getQuestCardForm(context, widget.docId),
    );
  }

  Form getQuestCardForm(BuildContext context, String docId) {
    // Important: We now use a local controller for each field to track changes
    final titleController =
        TextEditingController(text: Utils.capitalizeTitle(_questCard.title));
    final gameSystemController =
        TextEditingController(text: _questCard.gameSystem);
    final editionController = TextEditingController(text: _questCard.edition);
    final levelController = TextEditingController(text: _questCard.level);
    final pageLengthController =
        TextEditingController(text: _questCard.pageLength?.toString() ?? '');
    final authorsController =
        TextEditingController(text: _questCard.authors?.join(", ") ?? '');
    final productTitleController = TextEditingController(
        text: Utils.capitalizeTitle(_questCard.productTitle));
    final publisherController =
        TextEditingController(text: _questCard.publisher);
    final yearController =
        TextEditingController(text: _questCard.publicationYear);
    final genreController = TextEditingController(text: _questCard.genre);
    final settingController = TextEditingController(text: _questCard.setting);
    final environmentsController =
        TextEditingController(text: _questCard.environments?.join(", ") ?? '');
    final linkController = TextEditingController(text: _questCard.link ?? '');
    final bossVillainsController =
        TextEditingController(text: _questCard.bossVillains?.join(", ") ?? '');
    final commonMonstersController = TextEditingController(
        text: _questCard.commonMonsters?.join(", ") ?? '');
    final notableItemsController =
        TextEditingController(text: _questCard.notableItems?.join(", ") ?? '');
    final summaryController = TextEditingController(text: _questCard.summary);

    // Add disposal of controllers
    Future.microtask(() {
      // Add disposal of controllers when widget is removed from tree
      for (final controller in [
        titleController,
        gameSystemController,
        editionController,
        levelController,
        pageLengthController,
        authorsController,
        productTitleController,
        publisherController,
        yearController,
        genreController,
        settingController,
        environmentsController,
        linkController,
        bossVillainsController,
        commonMonstersController,
        notableItemsController,
        summaryController
      ]) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) controller.dispose();
        });
      }
    });

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            _buildTextFieldWithController(
              label: 'Title',
              controller: titleController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            _buildTextFieldWithController(
              label: 'Game System',
              controller: gameSystemController,
            ),
            _buildTextFieldWithController(
              label: 'Edition',
              controller: editionController,
            ),
            _buildTextFieldWithController(
              label: 'Level',
              controller: levelController,
            ),
            _buildTextFieldWithController(
              label: 'Page Length',
              controller: pageLengthController,
              keyboardType: TextInputType.number,
            ),
            _buildTextFieldWithController(
              label: 'Authors (comma-separated)',
              controller: authorsController,
            ),
            _buildTextFieldWithController(
              label: 'Product Title',
              controller: productTitleController,
            ),
            _buildTextFieldWithController(
              label: 'Publisher',
              controller: publisherController,
            ),
            _buildTextFieldWithController(
              label: 'Publication Year',
              controller: yearController,
            ),
            _buildTextFieldWithController(
              label: 'Genre',
              controller: genreController,
            ),
            _buildTextFieldWithController(
              label: 'Setting',
              controller: settingController,
            ),
            _buildTextFieldWithController(
              label: 'Environments (comma-separated)',
              controller: environmentsController,
            ),
            _buildTextFieldWithController(
              label: 'Product Link',
              controller: linkController,
            ),
            _buildTextFieldWithController(
              label: 'Boss Villains (comma-separated)',
              controller: bossVillainsController,
            ),
            _buildTextFieldWithController(
              label: 'Common Monsters (comma-separated)',
              controller: commonMonstersController,
            ),
            _buildTextFieldWithController(
              label: 'Notable Items (comma-separated)',
              controller: notableItemsController,
              maxLines: null,
            ),
            _buildTextFieldWithController(
              label: 'Summary',
              controller: summaryController,
              maxLines: null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Debug values before update
                    log('Before update - Title: ${_questCard.title}');

                    // Directly update the quest card from controllers
                    _questCard.title = titleController.text;
                    _questCard.gameSystem = gameSystemController.text;
                    _questCard.edition = editionController.text;
                    _questCard.level = levelController.text;
                    _questCard.pageLength =
                        int.tryParse(pageLengthController.text);
                    _questCard.authors =
                        _processListField(authorsController.text);
                    _questCard.productTitle = productTitleController.text;
                    _questCard.publisher = publisherController.text;
                    _questCard.publicationYear = yearController.text;
                    _questCard.genre = genreController.text;
                    _questCard.setting = settingController.text;
                    _questCard.environments =
                        _processListField(environmentsController.text);
                    _questCard.link = linkController.text;
                    _questCard.bossVillains =
                        _processListField(bossVillainsController.text);
                    _questCard.commonMonsters =
                        _processListField(commonMonstersController.text);
                    _questCard.notableItems =
                        _processListField(notableItemsController.text);
                    _questCard.summary = summaryController.text;

                    // Debug values after update to confirm changes
                    log('After update - Title: ${_questCard.title}');
                    log('After update - Game System: ${_questCard.gameSystem}');
                    log('After update - Authors: ${_questCard.authors}');

                    // Full card logging for debugging
                    log('Saving updated quest card: ${_questCard.toJson()}');

                    // Save to Firestore
                    if (docId.isEmpty) {
                      firestoreService.addQuestCard(_questCard);
                    } else {
                      log('Updating card with docId: $docId');
                      firestoreService.updateQuestCard(docId, _questCard);
                    }

                    // Navigate with the correct docId
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            QuestCardDetailsView(docId: docId),
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

  // Helper method to process comma-separated list fields
  List<String>? _processListField(String? value) {
    if (value == null || value.isEmpty) {
      return [];
    }
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // Updated to use TextEditingController instead of initialValue and onSaved
  Widget _buildTextFieldWithController({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int? maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
      ),
    );
  }
}
