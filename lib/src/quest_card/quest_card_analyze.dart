import 'dart:convert';
import 'dart:developer';

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
  final FirebaseStorageService firebaseStorageService =
      FirebaseStorageService();
  final FirebaseVertexaiService aiService = FirebaseVertexaiService();
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();
  final EmailService emailService = EmailService();
  final FirebaseFunctionsService functionsService = FirebaseFunctionsService();

  List<String> docIds = [];

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'txt', 'doc']);
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
              onPressed: _pickFile,
              child: Text('Pick a File'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FutureBuilder<List<String>>(
                      future: autoAnalyzeFile(),
                      builder: (context, AsyncSnapshot<List<String>> snapshot) {
                        if (snapshot.hasData) {
                          //log(snapshot.data!);
                          docIds = snapshot.data!;
                          return QuestCardListView(
                            questCardList: docIds,
                          );
                        } else {
                          return Center(child: CircularProgressIndicator());
                        }
                      },
                    ),
                  ),
                );
              },
              child: Text('Analyze File'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> autoAnalyzeFile() async {
    log("Auto analyze file");
    try {
      // Upload the file and get the URL
      String url;
      var mimeType = lookupMimeType(_file!.name);
      log(mimeType!);
      if (mimeType == 'application/pdf') {
        String allText = await functionsService.pdfToText(_file!);
        //log(allText);
        url = await firebaseStorageService.uploadTextFile(allText);
      } else {
        url = await firebaseStorageService.uploadFile(_file!);
      }
      // Analyze the file using AI service to determine contents (single or multiple)
      Map<String, dynamic> adventureType =
          await aiService.determineAdventureType(url);
      if (adventureType['adventureType'] == 'Single') {
        return analyzeFile();
      } else if (adventureType['adventureType'] == 'Multi') {
        return analyzeMultiFile();
      }
    } catch (e) {
      log("Error in analyzeFile: $e");
      rethrow; // Rethrow the exception after logging
    }
    return [];
  }

  Future<List<String>> analyzeFile() async {
    log("Analyze single quest file");
    try {
      // Upload the file and get the URL

      String url = await firebaseStorageService.uploadFile(_file!);

      // Analyze the file using AI service and decode the result
      Map<String, dynamic> questCardSchema =
          jsonDecode(await aiService.analyzeFile(url));
      QuestCard questCard = QuestCard.fromJson(questCardSchema);
      questCard.uploadedBy = auth.getCurrentUser().email;

      // Check for duplicates
      String? dupeId =
          await firestoreService.getQuestByTitle(questCard.title ?? '');
      //log("AF dupeId: $dupeId");

      if (dupeId != null) {
        // A duplicate is found
        log("Dupe uploaded: $dupeId ${questCard.title}");
        return [dupeId];
      } else {
        //check that it is an adventure:
        if (questCard.classification != 'Adventure') {
          //AI has determined it is not an adventure, send an email to admin
          emailService
              .sendNonAdventureEmailToAdmin(questCard.toJson().toString());
        }

        // No duplicate found, add the new quest card
        String docId = await firestoreService.addQuestCard(questCard);
        return [docId];
      }
    } catch (e) {
      log("Error in analyzeFile: $e");
      rethrow; // Rethrow the exception after logging
    }
  }

  Future<List<String>> analyzeMultiFile() async {
    log("Analyze multiple quest file");
    try {
      String url;
      var mimeType = lookupMimeType(_file!.name);
      log(mimeType!);
      if (mimeType == 'application/pdf') {
        String allText = await functionsService.pdfToText(_file!);
        //log(allText);
        url = await firebaseStorageService.uploadTextFile(allText);
      } else {
        url = await firebaseStorageService.uploadFile(_file!);
      }

      // Upload the file and get the URL

      List<String> questCards = [];
      // Analyze the file using AI service and decode the result
      List<Map<String, dynamic>> questCardSchema =
          await aiService.analyzeMultiFileQueries(url);
      for (var se in questCardSchema) {
        QuestCard q = QuestCard.fromJson(se);
        q.uploadedBy = auth.getCurrentUser().email;

        String? dupeId = await firestoreService.getQuestByTitle(q.title ?? '');

        if (dupeId != null) {
          // A duplicate is found
          log("Dupe uploaded: $dupeId ${q.title}");
          questCards.add(dupeId);
        } else {
          //check that it is an adventure:
          if (q.classification != 'Adventure') {
            //AI has determined it is not an adventure, send an email to admin
            emailService.sendNonAdventureEmailToAdmin(q.toJson().toString());
          }
          String docId = await firestoreService.addQuestCard(q);
          questCards.add(docId);
        }
      }
      log(jsonEncode(questCardSchema));
      return questCards;
    } catch (e, s) {
      log("Error in analyzeFile: $e");
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
