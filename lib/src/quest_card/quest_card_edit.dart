import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/services/firestore_service.dart';
import 'package:quest_cards/src/widgets/game_system_autocomplete.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added
import 'package:quest_cards/src/services/email_service.dart'; // Added

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
  Map<String, dynamic> _originalQuestCardData =
      {}; // Added to store original data
  bool _isLoading = true;
  final FirestoreService firestoreService = FirestoreService();
  final EmailService emailService = EmailService(); // Added
  User? _currentUser; // Added

  @override
  void initState() {
    super.initState();
    _questCard = QuestCard();
    _loadCurrentUser(); // Added
    if (widget.docId.isNotEmpty) {
      _loadQuestCardData();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadCurrentUser() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    // You might need to fetch custom claims or roles if you have an admin system
    // For now, we'll just use the UID and email.
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
          _originalQuestCardData = Map.from(data); // Store original data
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

    // Track standardized game system
    String? standardizedGameSystem = _questCard.standardizedGameSystem;

    // Add disposal of controllers
    Future.microtask(() {
      // Add disposal of controllers when widget is removed from tree
      for (final controller in [
        titleController,
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
            // Replace the game system text field with our autocomplete widget
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: GameSystemAutocompleteField(
                initialValue: _questCard.gameSystem,
                isRequired: false,
                onChanged: (value, standardized) {
                  // Update the standardized game system
                  standardizedGameSystem = standardized;
                  log('Game system changed to: $value, standardized as: $standardized');
                },
              ),
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
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    // Collect form data into _questCard ONCE
                    _questCard.title = titleController.text;
                    _questCard.standardizedGameSystem = standardizedGameSystem;
                    _questCard.edition = editionController.text;
                    _questCard.level = levelController.text;
                    _questCard.pageLength =
                        int.tryParse(pageLengthController.text);
                    _questCard.authors =
                        _processListField(authorsController.text);
                    _questCard.productTitle = productTitleController.text;
                    if (_questCard.productTitle == null ||
                        _questCard.productTitle!.trim().isEmpty) {
                      _questCard.productTitle = _questCard.title;
                    }
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

                    if (standardizedGameSystem != null) {
                      _questCard.systemMigrationStatus = 'completed';
                      _questCard.systemMigrationTimestamp = DateTime.now();
                    }

                    // Populate uploader information for new quest cards
                    if (widget.docId.isEmpty) { // This indicates a new quest card
                      log('[INFO] New card detected (docId is empty). Current _questCard.uploadedBy before update: ${_questCard.uploadedBy}');
                      if (_currentUser != null) {
                        _questCard.uploadedBy = _currentUser!.uid; // Store UID
                        _questCard.uploaderEmail = _currentUser!.email; // Store email
                        _questCard.uploadedTimestamp = DateTime.now(); // Store timestamp
                        log('[INFO] Set uploader info for new quest: UID: ${_currentUser!.uid}, Email: ${_currentUser!.email}, Timestamp: ${_questCard.uploadedTimestamp}');
                        log('[INFO] _questCard.uploadedBy after update: ${_questCard.uploadedBy}');
                      } else {
                        log('[ERROR] Current user is null when attempting to set uploader information for a new quest card.');
                      }
                    } else {
                        log('[INFO] Existing card detected (docId: ${widget.docId}). Uploader info not changed on _questCard object directly here.');
                    }

                    log('Updated _questCard from form: ${_questCard.toJson()}');

                    // Perform Authorization Check
                    log('[AUTH_CHECK] Starting permission checks for quest update/suggestion.');
                    log('[AUTH_CHECK] Current User UID: ${_currentUser?.uid}');
                    // Ensure you are logging the correct field for comparison.
                    // If 'uploadedBy' in Firestore stores the UID, this log is correct.
                    // If 'uploadedBy' in Firestore stores the email, this log will highlight the mismatch type.
                    log('[AUTH_CHECK] Original Uploader Identifier from _originalQuestCardData["uploadedBy"]: ${_originalQuestCardData['uploadedBy']}');

                    bool isAdmin = false;
                    if (_currentUser != null) {
                      final userRoles = await firestoreService
                          .getUserRoles(_currentUser!.uid);
                      isAdmin = userRoles?.contains('admin') ?? false;
                      log('[AUTH_CHECK] Fetched User Roles: $userRoles, Is Admin?: $isAdmin');
                    } else {
                      log('[AUTH_CHECK] Current user is null, cannot determine admin status.');
                    }

                    // Corrected: Compare current user's UID with the stored uploader UID.
                    // This assumes _originalQuestCardData['uploadedBy'] stores the UID.
                    final String? originalUploaderUid = _originalQuestCardData['uploadedBy'] as String?;
                    final bool isUploader = _currentUser != null &&
                        originalUploaderUid != null &&
                        originalUploaderUid == _currentUser!.uid;
                    log('[AUTH_CHECK] Is Uploader (UID match)?: $isUploader');

                    bool canUpdateDirectly = isAdmin || isUploader;
                    // For new cards, the creator should always be able to save it.
                    if (widget.docId.isEmpty) {
                        log('[AUTH_CHECK] New card: Allowing direct update.');
                        canUpdateDirectly = true;
                    }

                    log('[AUTH_CHECK] Decision: Can update directly?: $canUpdateDirectly');

                    if (canUpdateDirectly) {
                      log('[ACTION] User is admin or uploader. Attempting direct quest card update.');
                      if (docId.isEmpty) {
                        firestoreService
                            .addQuestCard(_questCard)
                            .then((newDocId) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  QuestCardDetailsView(docId: newDocId),
                            ),
                          );
                        }).catchError((error) {
                          log('[ERROR] Failed to add quest card: $error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error adding quest: $error')),
                          );
                        });
                      } else {
                        firestoreService
                            .updateQuestCard(docId, _questCard)
                            .then((_) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  QuestCardDetailsView(docId: docId),
                            ),
                          );
                        }).catchError((error) {
                          log('[ERROR] Failed to update quest card: $error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error updating quest: $error')),
                          );
                        });
                      }
                    } else {
                      log('[ACTION] User is not admin or uploader. Preparing to send edit suggestion.');
                      Map<String, dynamic> changes = {};
                      Map<String, dynamic> updatedJson = _questCard.toJson();

                      _originalQuestCardData.forEach((key, oldValue) {
                        if (updatedJson.containsKey(key) &&
                            updatedJson[key] != oldValue) {
                          changes[key] = {
                            'old': oldValue,
                            'new': updatedJson[key]
                          };
                        }
                      });
                      // Add new keys that were not in original
                      updatedJson.forEach((key, newValue) {
                        if (!_originalQuestCardData.containsKey(key) &&
                            newValue != null) {
                          changes[key] = {'old': null, 'new': newValue};
                        }
                      });

                      if (changes.isNotEmpty) {
                        try {
                          await emailService
                              .sendQuestEditSuggestionEmailToAdmin(
                            docId.isNotEmpty
                                ? docId
                                : _questCard.id ??
                                    "NEW_QUEST_SUGGESTION", // Use actual docId or questCard.id
                            _currentUser?.email ?? 'anonymous@questable.app',
                            _questCard.title ?? 'Untitled Quest',
                            changes,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Your edit suggestion has been sent for review.')),
                          );
                        } catch (e) {
                          log('[ERROR] Failed to send suggestion email: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error sending suggestion: $e')),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('No changes detected to suggest.')),
                        );
                      }
                      // Navigate back or to a neutral page
                      Navigator.pop(context);
                    }
                  } else {
                    log('Form validation failed.');
                    // Optionally, show a SnackBar if form is invalid
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Please correct the errors in the form.')),
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
