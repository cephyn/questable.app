import 'dart:convert';
import 'dart:developer';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/foundation.dart';
import 'package:quest_cards/src/quest_card/quest_card.dart';

import 'firebase_storage_service.dart';

class FirebaseVertexaiService {
  final FirebaseStorageService firebaseStorageService =
      FirebaseStorageService();
  late GenerativeModel model;
  final String systemInstruction =
      'You are an expert at extracting information from text documents and producing structured data. Correct any spelling mistakes. Your task is to extract relevant details from the provided text and output it in JSON format according to the provided response schema.';
  late Schema returnSchema;

  final String aiModel = 'gemini-2.0-flash';

  FirebaseVertexaiService() {
    Schema returnSchema = QuestCard.aiJsonSchema();
    model = FirebaseVertexAI.instance.generativeModel(
        model: aiModel,
        generationConfig: GenerationConfig(
            responseMimeType: 'application/json', responseSchema: returnSchema),
        systemInstruction: Content.system(systemInstruction));
  }

  //set return schema

  Future<String> analyzeFile(String fileUrl) async {
    //get file from storage
    Reference fileReference = firebaseStorageService.getFileReference(fileUrl);
    //get mime file type
    final FullMetadata metadata = await fileReference.getMetadata();
    final String? mimeType = metadata.contentType;
    returnSchema = QuestCard.aiJsonSchema();
    model = FirebaseVertexAI.instance.generativeModel(
        model: aiModel,
        generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: returnSchema));

    //set prompt
    final TextPart prompt = TextPart(
        "Analyze this adventure for a role-playing game. Extract the information necessary to populate the fields in the response schema. Generate an empty string for the link field.");

    //send to AI
    final filePart = FileData(
        mimeType!, firebaseStorageService.getStorageUrl(fileReference));
    final tokenCount = await model.countTokens([
      Content.multi([prompt, filePart])
    ]);
    log('Token count: ${tokenCount.totalTokens}, billable characters: ${tokenCount.totalBillableCharacters}');

    final response = await model.generateContent([
      Content.multi([prompt, filePart])
    ]);
    //delete file
    await fileReference.delete();

    //return reponse
    //log(response.text!);
    return response.text!;
  }

  Future<List<Map<String, dynamic>>> analyzeMultiFileQueries(
      String fileUrl) async {
    Schema returnSchema = QuestCard.aiJsonSchemaMulti();
    model = FirebaseVertexAI.instance.generativeModel(
        model: aiModel,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: returnSchema,
        ));
    List<Map<String, dynamic>> allAdventures = [];
    //get file from storage
    Reference fileReference = firebaseStorageService.getFileReference(fileUrl);
    //get mime file type
    FullMetadata metadata = await fileReference.getMetadata();
    String? mimeType = metadata.contentType;

    // 1. Identify Title Pages
    Map<String, dynamic> titlesMap =
        await extractAdventureTitles(fileReference, mimeType!);

    log("Titles: $titlesMap");
    List<String> titles = [];
    for (Map<String, dynamic> title in titlesMap['titles']) {
      titles.add(title['title']);
    }
    log("Titles: $titles");
    //Add a boundary index for the last title
    //2. Extract global information
    Map<String, dynamic> globalInfo =
        await extractGlobalInformation(fileReference, mimeType);

    //need to create a file of the subset of the text
    //process the file
    //delete the file

    // 3. Iterate and extract specific information for each adventure
    log("Titles: ${titles.length}");
    for (int i = 0; i < titles.length; i++) {
      String title = titles[i];
      log("Processing title: $i $title");
      Uint8List? downloadedText = await fileReference.getData();
      String text = utf8.decode(downloadedText!);

      log("searching for: $title");
      int startIndex = text
          .toLowerCase()
          .lastIndexOf(title.toLowerCase()); //text.indexOf(startPhrase);

      int endIndex = text.length - 1;

      if (i != (titles.length - 1)) {
        log("searching for: ${titles[i + 1]}");
        endIndex = text.toLowerCase().lastIndexOf(titles[i + 1].toLowerCase());
      }

      log("final indices: $startIndex $endIndex");
      if (startIndex >= endIndex || startIndex == -1 || endIndex == -1) {
        //skip
        log("Skipping title: $title - $startIndex greater than $endIndex");
      } else {
        String subText = text.substring(startIndex, endIndex);
        //log("Subtext: $subText");
        String subUrl = await firebaseStorageService.uploadTextFile(subText);
        Reference subFileReference =
            firebaseStorageService.getFileReference(subUrl);

        Map<String, dynamic> adventureObject = {
          "id": "", //You may set a specific method of id generation here
          "title": title,
          "productTitle": globalInfo["productTitle"],
          "gameSystem": globalInfo["gameSystem"],
          "publisher": globalInfo["publisher"],
          "edition": globalInfo["edition"],
          "publicationYear": globalInfo["publicationYear"],
          "link":
              "" //You would extract this with an additional step based on the link pattern within the document
        };

        Map<String, dynamic> individualData =
            await extractIndividualInformation(subFileReference, mimeType,
                title); //Extract individual information
        adventureObject.addAll(individualData);
        //await subFileReference.delete();
        allAdventures.add(adventureObject);
      }
    }
    //delete file

    await fileReference.delete();
    log(allAdventures.toString());
    return allAdventures;
  }

  Future<Map<String, dynamic>> extractAdventureTitles(
      Reference fileReference, String mimeType) async {
    TextPart prompt = TextPart('''
Your task is to identify individual adventure scenarios within the provided text. For each adventure, extract the following information: title: The title of the adventure scenario. This is typically a short phrase in all caps or title case, often followed by a level range indication (e.g., "FOUR 1ST- TO 2ND-LEVEL PCS").
''');
    Schema returnSchema = Schema.object(properties: {
      'titles': Schema.array(
          items: Schema.object(properties: {
        'title': Schema.string(description: 'Title of a specific adventure.'),
      }))
    });

    return await processAiRequest(returnSchema, mimeType, fileReference,
        prompt); //Return a list of adventure titles.
  }

  Future<Map<String, dynamic>> extractGlobalInformation(
      Reference fileReference, String mimeType) async {
    Schema returnSchema = QuestCard.globalQuestData();
    TextPart prompt = TextPart('''
Extract and format key game information from the provided document.

Instructions:

1. **Identify and extract the following information:**

    *   **Game System:** The name of the game system (e.g., D&D 5e, Pathfinder, GURPS, Call of Cthulhu). Be as specific as possible (e.g., "Dungeons & Dragons" rather than just "D&D").
    *   **Publisher:** The name of the company that published the document or the game.
    *   **Product Title:** The title of the document or product.
    *   **Publication Year:** The year the document was published or released. Extract only the year as a four-digit number (e.g., 2023, not "Copyright 2023").
    *   **Link:** The URL or web address of the document, if available. Ensure it is a valid URL.

2. **Handle missing or ambiguous information:**

    *   If any of the above information is not explicitly found in the document, return an empty string ("") for that specific field.
    *   If the information is ambiguous or presented in multiple ways, prioritize information found in prominent locations like the cover, title page, or copyright notice.

3. **Ensure accuracy and consistency:**

    *   Correct any minor spelling errors in the extracted information.
    *   Use consistent formatting for names (e.g., "First Name Last Name").

4. **Return a JSON object according to the provided response schema. Provide *only* the JSON output. Do not include any additional explanations or commentary.**
        ''');

    return await processAiRequest(returnSchema, mimeType, fileReference,
        prompt); // return those keys with their values in a map object
  }

  Future<Map<String, dynamic>> extractIndividualInformation(
      Reference fileReference, String mimeType, String title) async {
    Schema returnSchema = QuestCard.individualQuestData();
    TextPart prompt = TextPart('''
Extract and format key information about the adventure titled "$title" from the provided document.

Instructions:

1. **Extract and format the following information:**

    *   **Classification Type:** Classify the section of the document as an "Adventure", "Rulebook", "Supplement", or "Other" based on its primary purpose.
    *   **Level Range:** The recommended player level range for the adventure (e.g., "Levels 1-4", "Levels 5-10").
    *   **Game System:** The game system used for the adventure (e.g., D&D 5e, Pathfinder, Call of Cthulhu). Be as specific as possible (e.g., "Dungeons & Dragons 5th Edition").
    *   **Genre:** The adventure's genre (e.g., fantasy, horror, sci-fi, gothic).
    *   **Authors:** The names of the adventure's authors or creators.
    *   **Setting:** The adventure's setting (e.g., Forgotten Realms, Eberron, Ravenloft).
    *   **Environments:** The primary environments featured in the adventure (e.g., forests, caves, cities, underwater). List multiple environments if applicable, separated by commas.
    *   **Boss Villains:** The names of major antagonists or boss encounters. List multiple villains if applicable, separated by commas.
    *   **Common Monsters:** Types of monsters frequently encountered in the adventure. List multiple monster types if applicable, separated by commas.
    *   **Notable Items:** Unique or important items found within the adventure. List multiple items if applicable, separated by commas.
    *   **Summary:** A concise summary of the adventure's plot or main events. Aim for 3-4 sentences.

2. **Handle missing or ambiguous information:**

    *   If any of the above information is not explicitly found within the defined section, return an empty string ("") for that field.

3. **Ensure accuracy and consistency:**

    *   Correct any minor spelling errors in the extracted information.
    *   Use consistent formatting for names (e.g., "First Name Last Name").

4. **Return a JSON object according to the provided schema: Provide *only* the JSON output. Do not include any additional explanations or commentary.**
''');

    return await processAiRequest(returnSchema, mimeType, fileReference,
        prompt); // return those keys with their values in a map object
  }

  Future<Map<String, dynamic>> determineAdventureType(String url) async {
    //get file from storage
    Reference fileReference = firebaseStorageService.getFileReference(url);
    //get mime file type
    FullMetadata metadata = await fileReference.getMetadata();
    String? mimeType = metadata.contentType;
    returnSchema = QuestCard.adventureTypeSchema();
    TextPart prompt = TextPart(
        "Determine if the file contains a single adventure or a collection of adventures. Return the type as defined in the response schema.");
    Map<String, dynamic> adventureType =
        await processAiRequest(returnSchema, mimeType!, fileReference, prompt);
    log(adventureType.toString());
    return adventureType;
  }

  Future<dynamic> processAiRequest(Schema returnSchema, String mimeType,
      Reference fileReference, TextPart prompt) async {
    model = FirebaseVertexAI.instance.generativeModel(
      model: aiModel,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: returnSchema,
        temperature: 0.7,
        topP: 0.95,
        topK: 40,
      ),
      systemInstruction: Content.system(systemInstruction),
    );
    //Make an API call to classify the document segment.
    FileData filePart =
        FileData(mimeType, firebaseStorageService.getStorageUrl(fileReference));
    var tokenCount = await model.countTokens([
      Content.multi([prompt, filePart])
    ]);

    log('Token count: ${tokenCount.totalTokens}, billable characters: ${tokenCount.totalBillableCharacters}');

    var response = await model.generateContent([
      Content.multi([prompt, filePart])
    ]);
    //log(response.text!);
    return jsonDecode(response.text!);
  }
}
