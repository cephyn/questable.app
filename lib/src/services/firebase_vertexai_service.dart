import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:quest_cards/src/quest_card/quest_card.dart';
import 'package:quest_cards/src/services/purchase_link_service.dart';

import 'firebase_storage_service.dart';
import 'dart:math' hide log;

/// Service to interact with Firebase Vertex AI for RPG adventure extraction
class FirebaseVertexaiService {
  final FirebaseStorageService firebaseStorageService =
      FirebaseStorageService();

  // AI configuration
  final String aiModel = 'gemini-2.5-flash';
  final String systemInstruction =
      'You are an expert at extracting RPG Adventures from text documents and producing structured data. Correct any spelling mistakes. Your task is to extract relevant details from the provided text and output it in JSON format according to the provided response schema. The definition of an RPG Adventure is: An RPG adventure is a narrative-driven scenario within a role-playing game where players guide characters through challenges and exploration to advance a storyline.';

  // Model generation parameters
  final double temperature = 0.7;
  final double topP = 0.95;
  final int topK = 40;

  /// Creates a GenerativeModel with the specified schema
  GenerativeModel _createModel(Schema schema,
      {bool setSystemInstruction = true}) {
    return FirebaseAI.googleAI().generativeModel(
      model: aiModel,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        temperature: temperature,
        topP: topP,
        topK: topK,
      ),
      systemInstruction:
          setSystemInstruction ? Content.system(systemInstruction) : null,
    );
  }

  /// Analyze a single file and extract RPG adventure data
  Future<String> analyzeFile(String fileUrl) async {
    try {
      // Get file from storage
      Reference fileReference =
          firebaseStorageService.getFileReference(fileUrl)!;

      // Get file metadata
      final FullMetadata metadata = await fileReference.getMetadata();
      final String? mimeType = metadata.contentType;

      if (mimeType == null) {
        throw Exception('Could not determine file mimetype');
      }

      // Configure model with single adventure schema
      final Schema adventureSchema = QuestCard.aiJsonSchema();
      final model = _createModel(adventureSchema);

      // Set prompt and prepare file data
      final TextPart prompt = TextPart(
          "Analyze this adventure for a role-playing game. Extract the information necessary to populate the fields in the response schema. Generate an empty string for the link field.");
      final filePart = FileData(
          mimeType, await firebaseStorageService.getStorageUrl(fileReference));

      // Count tokens for logging
      final tokenCount = await model.countTokens([
        Content.multi([prompt, filePart])
      ]);
      log('Token count: ${tokenCount.totalTokens}, billable characters: ${tokenCount.totalBillableCharacters}');

      // Generate content
      final response = await model.generateContent([
        Content.multi([prompt, filePart])
      ]);

      // Clean up: delete file after processing
      await fileReference.delete();

      // Return response text
      return response.text ?? '{}';
    } catch (e) {
      log('Error in analyzeFile: $e');
      return '{"error": "${e.toString().replaceAll('"', '\\"')}"}';
    }
  }

  /// Determine if the provided file contains a single adventure or multiple adventures
  Future<Map<String, dynamic>> determineAdventureType(String url) async {
    Reference? fileReference;
    try {
      fileReference = firebaseStorageService.getFileReference(url);
      FullMetadata metadata = await fileReference!.getMetadata();
      String? mimeType = metadata.contentType;

      if (mimeType == null) {
        throw Exception('Could not determine file mimetype');
      }

      Schema typeSchema = QuestCard.adventureTypeSchema();
      TextPart prompt = TextPart(
          "Determine if the file contains a single adventure or a collection of adventures. Return the type as defined in the response schema.");

      Map<String, dynamic> adventureType =
          await processAiRequest(typeSchema, mimeType, fileReference, prompt);

      log('Adventure type determined: ${adventureType.toString()}');
      return adventureType;
    } catch (e) {
      log('Error in determineAdventureType: $e');
      return {'type': 'unknown', 'error': e.toString()};
    }
    // We don't delete the file here as it's needed for subsequent processing
    // The calling method (autoAnalyzeFile in QuestCardAnalyze) will handle deletion
    // through analyzeSingleFile or analyzeMultiFile
  }

  /// Process multiple adventures from a single file
  Future<List<Map<String, dynamic>>> analyzeMultiFileQueries(
      String fileUrl) async {
    List<Map<String, dynamic>> allAdventures = [];
    Reference? fileReference;

    try {
      // Get file reference and metadata
      fileReference = firebaseStorageService.getFileReference(fileUrl);
      FullMetadata metadata = await fileReference!.getMetadata();
      String? mimeType = metadata.contentType;

      if (mimeType == null) {
        throw Exception('Could not determine file mimetype');
      }

      // 1. Identify title pages (adventure boundaries)
      Map<String, dynamic> titlesMap =
          await extractAdventureTitles(fileReference, mimeType);
      log("Titles identified: ${titlesMap['titles']?.length ?? 0}");

      List<String> adventureTitles = [];
      for (Map<String, dynamic> title in titlesMap['titles'] ?? []) {
        adventureTitles.add(title['title']);
      }

      if (adventureTitles.isEmpty) {
        log("No adventure titles found in document");
        return [];
      }

      // 2. Extract global information applicable to all adventures
      Map<String, dynamic> globalInfo =
          await extractGlobalInformation(fileReference, mimeType);
      log("Global info extracted: ${globalInfo.keys.join(', ')}");

      var purchaseLinkFuture = _searchForPurchaseLink(globalInfo);
      String? purchaseLink = await purchaseLinkFuture;
      if (purchaseLink!.isNotEmpty) {
        globalInfo['link'] = purchaseLink;
        log('Purchase link found: ${globalInfo['link']}');
      }

      // 3. Process each individual adventure
      Uint8List? downloadedText = await fileReference.getData();
      if (downloadedText == null) {
        throw Exception('Could not download file data');
      }

      String fullText = utf8.decode(downloadedText);
      List<String> lines;
      lines = fullText.split(RegExp(r'\r?\n'));
      if (lines.isNotEmpty && lines.last.isEmpty) {
        lines.removeLast();
      }
      // --- Find Adventure Starts ---
      final adventureStarts = _findAdventureStarts(lines, adventureTitles);
      final numAdventures = adventureStarts.length;

      for (int i = 0; i < numAdventures; i++) {
        final startLineNum = adventureStarts[i].key;
        final title = adventureStarts[i].value;

        // Determine the end line number for the current adventure
        final int endLineNum;
        if (i < numAdventures - 1) {
          // End line is the line *before* the next adventure starts
          endLineNum = adventureStarts[i + 1].key;
        } else {
          // This is the last adventure, so it goes to the end of the file
          endLineNum = lines.length;
        }
        if (startLineNum >= endLineNum) {
          log("  Warning: No content found for '$title' (start line ${startLineNum + 1} >= end line $endLineNum). Skipping.");
          continue;
        }
        final adventureContentLines = lines.sublist(startLineNum, endLineNum);
        final adventureContent = adventureContentLines.join('\n');

        String subUrl =
            await firebaseStorageService.uploadTextFile(adventureContent);
        Reference subFileReference =
            firebaseStorageService.getFileReference(subUrl)!;

        try {
          // Create adventure object with global info
          Map<String, dynamic> adventureObject = {
            "id": "", // ID generation would happen elsewhere
            "title": title,
            "productTitle": globalInfo["productTitle"] ?? "",
            "gameSystem": globalInfo["gameSystem"] ?? "",
            "publisher": globalInfo["publisher"] ?? "",
            "edition": globalInfo["edition"] ?? "",
            "publicationYear": globalInfo["publicationYear"] ?? "",
            "link": globalInfo["link"] ?? "",
          };

          // Extract adventure-specific information
          Map<String, dynamic> individualData =
              await extractIndividualInformation(
                  subFileReference, mimeType, title);

          // Use global authors if individual authors aren't specified
          if ((individualData['authors'] ?? "").isEmpty) {
            individualData['authors'] = globalInfo['authors'] ?? "";
          }

          // Merge global and individual data
          adventureObject.addAll(individualData);
          allAdventures.add(adventureObject);
        } catch (e) {
          log("Error processing adventure '$title': $e");
        } finally {
          // Clean up temporary files
          await subFileReference
              .delete()
              .catchError((e) => log("Error deleting temp file: $e"));
        }
      }

      log("Successfully processed ${allAdventures.length} adventures");
      return allAdventures;
    } catch (e) {
      log("Error in analyzeMultiFileQueries: $e");
      return [];
    } finally {
      // Clean up the original file
      if (fileReference != null) {
        await fileReference
            .delete()
            .catchError((e) => log("Error deleting file: $e"));
      }
    }
  }

  /// Extract titles of all adventures in the document
  Future<Map<String, dynamic>> extractAdventureTitles(
      Reference fileReference, String mimeType) async {
    Schema titleSchema = Schema.object(properties: {
      'titles': Schema.array(
          items: Schema.object(properties: {
        'title': Schema.string(description: 'Title of a specific adventure.'),
      }))
    });

    TextPart prompt = TextPart('''
Your task is to identify individual adventure scenarios within the provided text. For each adventure, extract the following information: title: The title of the adventure scenario. This is typically a short phrase in all caps or title case, often followed by a level range indication (e.g., "FOUR 1ST- TO 2ND-LEVEL PCS").
''');

    return await processAiRequest(titleSchema, mimeType, fileReference, prompt);
  }

  /// Extract global information applicable to all adventures in the document
  Future<Map<String, dynamic>> extractGlobalInformation(
      Reference fileReference, String mimeType) async {
    Schema globalSchema = QuestCard.globalQuestData();
    TextPart prompt = TextPart('''
Extract and format key game information from the provided document.

Instructions:

1. **Identify and extract the following information:**

    *   **Game System:** The name of the game system (e.g., D&D 5e, Pathfinder, GURPS, Call of Cthulhu). Be as specific as possible (e.g., "Dungeons & Dragons" rather than just "D&D").
    *   **Publisher:** The name of the company that published the document or the game.
    *   **Product Title:** The title of the document or product.
    *   **Publication Year:** The year the document was published or released. Extract only the year as a four-digit number (e.g., 2023, not "Copyright 2023").
    *   **Link:** The URL or web address of the document, if available. Ensure it is a valid URL.
    *   **Authors:** The names of the adventure's authors or creators.

2. **Handle missing or ambiguous information:**

    *   If any of the above information is not explicitly found in the document, return an empty string ("") for that specific field.
    *   If the information is ambiguous or presented in multiple ways, prioritize information found in prominent locations like the cover, title page, or copyright notice.

3. **Ensure accuracy and consistency:**

    *   Correct any minor spelling errors in the extracted information.
    *   Use consistent formatting for names (e.g., "First Name Last Name").

4. **Return a JSON object according to the provided response schema. Provide *only* the JSON output. Do not include any additional explanations or commentary.**
        ''');

    return await processAiRequest(
        globalSchema, mimeType, fileReference, prompt);
  }

  /// Extract information specific to an individual adventure
  Future<Map<String, dynamic>> extractIndividualInformation(
      Reference fileReference, String mimeType, String title) async {
    Schema individualSchema = QuestCard.individualQuestData();
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

    return await processAiRequest(
        individualSchema, mimeType, fileReference, prompt);
  }

  /// Generic method to make AI requests with proper error handling
  Future<Map<String, dynamic>> processAiRequest(Schema schema, String mimeType,
      Reference fileReference, TextPart prompt) async {
    try {
      // Check if user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        log('Error: User is not authenticated');
        return {
          'error':
              'User is not authenticated. Please sign in to access this feature.'
        };
      }

      GenerativeModel requestModel = _createModel(schema);

      // Get an authenticated URL for the file
      String fileUrl =
          await firebaseStorageService.getStorageUrl(fileReference);
      log('Using authenticated URL for file access: $fileUrl');

      // Create file part for the model
      FileData filePart = FileData(mimeType, fileUrl);

      try {
        // Get token counts for monitoring/logging
        var tokenCount = await requestModel.countTokens([
          Content.multi([prompt, filePart])
        ]);

        log('Token count: ${tokenCount.totalTokens}, billable characters: ${tokenCount.totalBillableCharacters}');
      } catch (tokenCountError) {
        // Continue even if token counting fails
        log('Warning: Failed to count tokens: $tokenCountError');
      }

      // Make the actual API request
      var response = await requestModel.generateContent([
        Content.multi([prompt, filePart])
      ]);

      if (response.text == null || response.text!.isEmpty) {
        return {'error': 'Empty response from AI model'};
      }

      return jsonDecode(response.text!);
    } catch (e) {
      log('Error in AI request processing: $e');
      if (e.toString().contains('permission')) {
        log('Permission error details: This may be due to insufficient Firebase permissions.');
        // Try to get the current user email for debugging
        final email =
            FirebaseAuth.instance.currentUser?.email ?? 'Not signed in';
        log('Current user email: $email');
      }
      return {'error': e.toString()};
    }
  }

  // --- Helper Function to Find Adventure Start Lines ---
  List<MapEntry<int, String>> _findAdventureStarts(
      List<String> lines, List<String> adventureTitles) {
    // Map: Original Title -> List of line numbers where it was found
    final foundOccurrences = <String, List<int>>{};
    // Map: Normalized Title (lowercase, trimmed) -> Original Title
    final normalizedTitles = <String, String>{};

    for (final title in adventureTitles) {
      normalizedTitles[title.trim().toLowerCase()] = title;
      // Initialize occurrence list for each expected title
      foundOccurrences[title] = [];
    }

    log("Scanning file for titles...");
    for (int i = 0; i < lines.length; i++) {
      final normalizedLine = lines[i].trim().toLowerCase();

      // Check if the normalized line exactly matches a normalized title
      if (normalizedTitles.containsKey(normalizedLine)) {
        final originalTitle = normalizedTitles[normalizedLine]!;
        foundOccurrences[originalTitle]!.add(i);
        // print("  Found potential title '$originalTitle' on line ${i + 1}");
      }
      // Optional: Add more sophisticated matching here if needed
    }

    log("\nDetermining likely start lines based on last occurrence...");
    final potentialStarts = <MapEntry<int, String>>[];
    final foundTitles = <String>{};

    foundOccurrences.forEach((title, lineNumbers) {
      if (lineNumbers.isNotEmpty) {
        // Heuristic: Assume the *last* occurrence marks the start
        final startLine = lineNumbers.reduce(max); // Find the max line number
        potentialStarts.add(MapEntry(startLine, title));
        foundTitles.add(title);
        log("  Selected line ${startLine + 1} as start for '$title'");
      }
    });

    // Report any titles that were *never* found
    for (final expectedTitle in adventureTitles) {
      if (!foundTitles.contains(expectedTitle)) {
        log("  WARNING: Title '$expectedTitle' not found in the text.");
      }
    }

    if (potentialStarts.isEmpty) {
      log("ERROR: No adventure titles were found matching the heuristic in the file.");
      return [];
    }

    // Sort the identified starts by line number (the MapEntry key)
    potentialStarts.sort((a, b) => a.key.compareTo(b.key));

    log("\nIdentified adventure start points (sorted):");
    for (final entry in potentialStarts) {
      log("  Line ${entry.key + 1}: ${entry.value}");
    }

    return potentialStarts;
  }

  /// Searches for a purchase link based on metadata
  Future<String?> _searchForPurchaseLink(Map<String, dynamic> metadata) async {
    if (metadata['productTitle']?.isEmpty ?? true) {
      return null;
    }

    try {
      log('Searching for purchase link for ${metadata['productTitle']}');

      // Use the PurchaseLinkService to find a purchase link
      //final purchaseLinkService = PurchaseLinkService();

      // Run in a separate isolate to avoid blocking the main thread
      return compute(_isolatedPurchaseLinkSearch, metadata);
    } catch (e) {
      log('Error in purchase link search: $e');
      return null;
    }
  }

  // This static method runs in a separate isolate
  static Future<String?> _isolatedPurchaseLinkSearch(
      Map<String, dynamic> metadata) async {
    final purchaseLinkService = PurchaseLinkService();
    try {
      return await purchaseLinkService.findPurchaseLink(metadata);
    } finally {
      purchaseLinkService.dispose();
    }
  }
}
