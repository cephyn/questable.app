import 'dart:convert';
import 'dart:developer';
// Import needed for WriteBatch
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:quest_cards/src/services/email_service.dart';
import 'package:quest_cards/src/services/firebase_functions_service.dart';
import 'package:quest_cards/src/services/firebase_storage_service.dart';

import '../services/firebase_auth_service.dart';
import '../services/firebase_vertexai_service.dart';
import '../services/firestore_service.dart';
import '../util/utils.dart';
import 'quest_card.dart';
import 'quest_card_list_view.dart';

class QuestCardAnalyze extends StatefulWidget {
  const QuestCardAnalyze({super.key});

  @override
  State<QuestCardAnalyze> createState() => _QuestCardAnalyzeState();
}

class _QuestCardAnalyzeState extends State<QuestCardAnalyze> {
  PlatformFile? _file;
  String? _fileName;
  bool _isAnalyzing = false; // State variable for loading indicator

  final FirebaseStorageService firebaseStorageService =
      FirebaseStorageService();
  final FirebaseVertexaiService aiService = FirebaseVertexaiService();
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();
  final EmailService emailService = EmailService();
  final FirebaseFunctionsService functionsService = FirebaseFunctionsService();

  // Removed docIds list as it's returned by the futures

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'txt',
          'doc',
          'docx',
          'rtf',
          'html',
          'md',
          'json'
        ]);
    if (result != null) {
      setState(() {
        _file = result.files.single;
        _fileName = _file!.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle("Analyze File");
    return Scaffold(
      appBar: AppBar(title: Text('Upload a File')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _file?.name != null
                  ? 'Selected File: $_fileName'
                  : 'No file selected.',
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  _isAnalyzing ? null : _pickFile, // Disable while analyzing
              child: Text('Pick a File'),
            ),
            SizedBox(height: 20),
            if (_isAnalyzing)
              CircularProgressIndicator() // Show indicator when analyzing
            else
              ElevatedButton(
                // Disable button if no file is selected or already analyzing
                onPressed:
                    _file == null || _isAnalyzing ? null : _handleAnalysis,
                child: Text('Analyze File'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAnalysis() async {
    if (_file == null) return;

    setState(() {
      _isAnalyzing = true; // Start loading indicator
    });

    try {
      List<String> resultingDocIds = await autoAnalyzeFile();
      // Navigate only after analysis is complete
      if (mounted) {
        // Check if the widget is still in the tree
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuestCardListView(
              questCardList: resultingDocIds,
            ),
          ),
        );
      }
    } catch (e) {
      log("Error during analysis: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing file: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false; // Stop loading indicator
        });
      }
    }
  }

  Future<List<String>> autoAnalyzeFile() async {
    log("Auto analyze file");
    if (_file == null) {
      throw Exception("No file selected for analysis.");
    }
    String? url; // Declare url outside the try block
    try {
      // Upload the file (or its converted content) ONCE
      var mimeType = lookupMimeType(_file!.name);
      log('File MIME type: ${mimeType ?? 'unknown'}');

      if (mimeType == 'application/pdf') {
        log('Converting PDF to Markdown...');
        String markdownContent = await functionsService.pdfToMd(_file!);
        log('Uploading Markdown content...');
        // Pass filename with extension for correct content type detection by storage if needed
        url = await firebaseStorageService.uploadTextFile(markdownContent);
      } else if (mimeType != null && mimeType.startsWith('text/')) {
        log('Uploading text file...');
        // Assuming uploadFile handles PlatformFile directly for text
        url = await firebaseStorageService.uploadFile(_file!);
      } else {
        // Handle other file types if necessary, or treat as generic upload
        log('Uploading generic file...');
        url = await firebaseStorageService.uploadFile(_file!);
      }
      log('File uploaded to: $url');

      // Analyze the file using AI service to determine contents
      log('Determining adventure type...');
      Map<String, dynamic> adventureTypeResult =
          await aiService.determineAdventureType(url);
      String adventureType = adventureTypeResult['adventureType'] ??
          'Single'; // Default to single if undetermined
      log('Determined adventure type: $adventureType');

      // Call the appropriate analysis function, passing the URL
      List<String> resultDocIds;
      if (adventureType == 'Single') {
        resultDocIds = await analyzeSingleFile(url); // Pass URL
      } else {
        // Assume 'Multi' or default to multi-processing
        resultDocIds = await analyzeMultiFile(url); // Pass URL
      }

      // // Delete the uploaded file after analysis is complete
      // log('Deleting uploaded file from storage, URL: $url');
      // bool success = await firebaseStorageService.deleteFile(url);
      // if (success) {
      //   log('File deleted successfully.');
      // } else {
      //   log('Failed to delete file. It may not exist or you may not have permission.');
      //   // Try to get more information about the URL
      //   log('URL format: ${url.startsWith('https://') ? 'HTTPS' : (url.startsWith('gs://') ? 'GS' : 'Other')}');
      //   try {
      //     var ref = firebaseStorageService.getFileReference(url);
      //     if (ref != null) {
      //       log('File reference exists, full path: ${ref.fullPath}');
      //     } else {
      //       log('Could not get file reference from URL');
      //     }
      //   } catch (refError) {
      //     log('Error getting file reference: $refError');
      //   }
      // }

      return resultDocIds;
    } catch (e, s) {
      log("Error in autoAnalyzeFile: $e");
      log("Stacktrace: $s");

      // Attempt to delete the file even if analysis failed
      if (url != null) {
        try {
          log('Deleting uploaded file after error...');
          bool success = await firebaseStorageService.deleteFile(url);
          if (success) {
            log('File deleted successfully.');
          } else {
            log('Failed to delete file after error. It may not exist or you may not have permission.');
          }
        } catch (deleteError) {
          log('Exception while trying to delete file: $deleteError');
          // We don't rethrow here to avoid masking the original error
        }
      }

      rethrow; // Rethrow the original exception after logging
    }
  }

  // Renamed analyzeFile to analyzeSingleFile for clarity and added url parameter
  Future<List<String>> analyzeSingleFile(String fileUrl) async {
    log("Analyze single quest file from URL: $fileUrl");
    try {
      // REMOVED redundant file upload

      // Analyze the file using AI service and decode the result
      log('Calling AI service for single file analysis...');
      Map<String, dynamic> questCardSchema =
          jsonDecode(await aiService.analyzeFile(fileUrl)); // Use passed URL
      QuestCard questCard = QuestCard.fromJson(questCardSchema);
      questCard.uploadedBy = auth.getCurrentUser().email;
      log('AI analysis complete. Title: ${questCard.title}');

      // Check for duplicates
      log('Checking for duplicate title: ${questCard.title}');
      String? dupeId =
          await firestoreService.getQuestByTitle(questCard.title ?? '');

      if (dupeId != null) {
        // A duplicate is found
        log("Duplicate found: $dupeId for title '${questCard.title}'. Returning existing ID.");
        return [dupeId];
      } else {
        log("No duplicate found for title '${questCard.title}'.");
        // Check classification
        if (questCard.classification != 'Adventure') {
          log('Classification is not Adventure (${questCard.classification}). Sending notification.');
          // AI has determined it is not an adventure, send an email to admin
          emailService
              .sendNonAdventureEmailToAdmin(questCard.toJson().toString());
        }

        // No duplicate found, add the new quest card
        log('Adding new quest card to Firestore...');
        String docId = await firestoreService.addQuestCard(questCard);
        log('New quest card added with ID: $docId');
        return [docId];
      }
    } catch (e, s) {
      log("Error in analyzeSingleFile: $e");
      log("Stacktrace: $s");
      rethrow; // Rethrow the exception after logging
    }
  }

  // Added url parameter and refactored for batch operations
  Future<List<String>> analyzeMultiFile(String fileUrl) async {
    log("Analyze multiple quest file from URL: $fileUrl");
    List<String> resultingDocIds = [];
    List<QuestCard> cardsToAdd = [];
    List<Map<String, dynamic>> nonAdventureCardsData = [];

    try {
      // REMOVED redundant file upload

      // Analyze the file using AI service
      log('Calling AI service for multi-file analysis...');
      List<Map<String, dynamic>> questCardSchemas =
          await aiService.analyzeMultiFileQueries(fileUrl); // Use passed URL
      log('AI analysis complete. Found ${questCardSchemas.length} potential quests.');

      if (questCardSchemas.isEmpty) {
        log('No quest data extracted by AI.');
        return [];
      }

      // --- Batch Duplicate Check ---
      List<String> titlesToCheck = questCardSchemas
          .map((schema) => (schema['title'] as String?)?.toLowerCase())
          .where((title) => title != null && title.isNotEmpty)
          .toList()
          .cast<String>(); // Ensure non-null, non-empty titles

      log('Checking ${titlesToCheck.length} titles for duplicates...');
      Map<String, String> existingTitles =
          await firestoreService.getQuestsByTitles(titlesToCheck);
      log('Found ${existingTitles.length} existing titles.');
      // --- End Batch Duplicate Check ---

      String currentUserEmail =
          auth.getCurrentUser().email ?? 'unknown@example.com';

      // Process results: identify duplicates and prepare new cards
      for (var schema in questCardSchemas) {
        QuestCard q = QuestCard.fromJson(schema);
        q.uploadedBy = currentUserEmail;
        String? titleLower = q.title?.toLowerCase();

        if (titleLower != null && existingTitles.containsKey(titleLower)) {
          // Duplicate found
          String dupeId = existingTitles[titleLower]!;
          log("Duplicate found: $dupeId for title '${q.title}'. Adding existing ID.");
          resultingDocIds.add(dupeId);
        } else {
          log("No duplicate found for title '${q.title}'. Preparing to add.");
          // Not a duplicate, prepare for batch write
          cardsToAdd.add(q);
          // Check classification for potential email notification
          if (q.classification != 'Adventure') {
            log("Classification is not Adventure (${q.classification}) for title '${q.title}'. Queuing notification.");
            nonAdventureCardsData
                .add(q.toJson()); // Store data for potential batched email
          }
        }
      }

      // --- Batch Write ---
      if (cardsToAdd.isNotEmpty) {
        log('Adding ${cardsToAdd.length} new quest cards in a batch...');
        List<String> newDocIds =
            await firestoreService.addMultipleQuestCards(cardsToAdd);
        resultingDocIds.addAll(newDocIds);
        log('Batch write complete. Added IDs: $newDocIds');
      }
      // --- End Batch Write ---

      // --- Handle Non-Adventure Notifications ---
      if (nonAdventureCardsData.isNotEmpty) {
        log('Sending notifications for ${nonAdventureCardsData.length} non-adventure items...');
        // Consider batching emails if your EmailService supports it
        for (var cardData in nonAdventureCardsData) {
          await emailService.sendNonAdventureEmailToAdmin(jsonEncode(cardData));
        }
        log('Non-adventure notifications sent.');
      }
      // --- End Notifications ---

      log('Total resulting document IDs: ${resultingDocIds.length}');
      return resultingDocIds;
    } catch (e, s) {
      log("Error in analyzeMultiFile: $e");
      log("Stacktrace: $s");
      rethrow; // Rethrow the exception after logging
    }
  }

  Future<List<String>> callTestFunction(String s) async {
    log("Calling test function");
    List<String> results = [];
    try {
      var x = await FirebaseFunctions.instance
          .httpsCallable('on_call_example')
          .call(
        {'text': s},
      );

      results.add(x.data.toString());
      log("Results: $results");
      return results;
    } catch (e) {
      log("Error in testFunction: $e");
      rethrow; // Rethrow the exception after logging
    }
  }
}
