import 'dart:convert';
import 'dart:developer';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/services/firebase_storage_service.dart';

import '../services/firebase_vertexai_service.dart';
import '../services/firestore_service.dart';
import '../util/utils.dart';
import 'quest_card.dart';
import 'quest_card_edit.dart';

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
  String? docId;

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
                    builder: (context) => FutureBuilder<String>(
                      future: analyzeFile(),
                      builder: (context, AsyncSnapshot<String> snapshot) {
                        if (snapshot.hasData) {
                          //log(snapshot.data!);
                          docId = snapshot.data!;
                          return EditQuestCard(
                            docId: docId!,
                          );
                        } else {
                          return Center(child: CircularProgressIndicator());
                        }
                      },
                    ),
                  ),
                );
              },
              child: Text('Upload File'),
            ),
            /*ElevatedButton(
              onPressed: () async {
                String docId = await analyzeFile();
                await sendToEdit(context, docId);
              },
              child: Text('Upload File'),
            ),*/
          ],
        ),
      ),
    );
  }

  /* sendToEdit(BuildContext context, String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditQuestCard(),
        settings: RouteSettings(arguments: {'docId': docId}),
      ),
    );
  }*/

  Future<String> analyzeFile() async {
    try {
      // Upload the file and get the URL
      String url = await firebaseStorageService.uploadFile(_file!);

      // Analyze the file using AI service and decode the result
      Map<String, dynamic> questCardSchema =
          jsonDecode(await aiService.analyzeFile(url));
      QuestCard questCard = QuestCard.fromJson(questCardSchema);

      // Check for duplicates
      String? dupeId =
          await firestoreService.getQuestByTitle(questCard.title ?? '');
      //log("AF dupeId: $dupeId");

      if (dupeId != null) {
        // A duplicate is found
        log("Dupe uploaded: $dupeId ${questCard.title}");
        return dupeId;
      } else {
        // No duplicate found, add the new quest card
        String docId = await firestoreService.addQuestCard(questCard);
        return docId;
      }
    } catch (e) {
      log("Error in analyzeFile: $e");
      rethrow; // Rethrow the exception after logging
    }
  }
}
