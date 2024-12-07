import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:quest_cards/src/quest_card/quest_card.dart';

import 'firebase_storage_service.dart';

class FirebaseVertexaiService {
  final FirebaseStorageService firebaseStorageService =
      FirebaseStorageService();
  var model;

  FirebaseVertexaiService(){
    final Schema returnSchema = QuestCard.aiJsonSchema();
    model =
      FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-1.5-flash',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: returnSchema)
        );
  
  }
  //set return schema
  

  Future<String> analyzeFile(String fileUrl) async {
    //get file from storage
    Reference fileReference = firebaseStorageService.getFileReference(fileUrl);
    //get mime file type
    final FullMetadata metadata = await fileReference.getMetadata();
    final String? mimeType = metadata.contentType;

    //set prompt
    final TextPart prompt = TextPart("Analyze this adventure for a role-playing game. Extract the information necessary to populate the fields in the response schema. Generate an empty string for the link field.");

    //send to AI
    final filePart = FileData(mimeType!, firebaseStorageService.getStorageUrl(fileReference));
    final tokenCount = await model.countTokens([
      Content.multi([prompt, filePart])
    ]);
    print(
        'Token count: ${tokenCount.totalTokens}, billable characters: ${tokenCount.totalBillableCharacters}');
    
    final response = await model.generateContent([
      Content.multi([prompt, filePart])
    ]);
    //delete file
    await fileReference.delete();

    //return reponse
    return response.text;
  }
}
