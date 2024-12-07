import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/services/firebase_storage_service.dart';

import '../services/firebase_vertexai_service.dart';
import '../services/firestore_service.dart';
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
  final FirebaseStorageService firebaseStorageService = FirebaseStorageService();
  final FirebaseVertexaiService aiService = FirebaseVertexaiService();
  final FirestoreService firestoreService = FirestoreService();

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf','txt','doc']
    );
    if (result != null) {
      setState(() {
        _file = result.files.single;
        _fileName = _file!.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: () async{
                String url = await firebaseStorageService.uploadFile(_file!);
                Map<String, dynamic> questCardSchema = jsonDecode(await aiService.analyzeFile(url));
                QuestCard questCard = QuestCard.fromJson(questCardSchema);
                String docId = await firestoreService.addQuestCard(questCard);
                //print(url);
                await Navigator.push(
                      context,
                      MaterialPageRoute(
                                  builder: (context) => const EditQuestCard(),
                                  settings: RouteSettings(
                                      arguments: {'docId': docId}),
                                ),
                    );
              },
              child: Text('Upload File'),
            ),
          ],
        ),
      ),
    );
  }
}
