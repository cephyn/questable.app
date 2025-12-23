import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:quest_cards/src/quest_card/quest_card.dart';
import 'package:quest_cards/src/services/purchase_link_service.dart';
import 'package:quest_cards/src/services/client_telemetry_service.dart';

import 'firebase_storage_service.dart';
import 'dart:math' hide log;

/// Service to interact with Firebase Vertex AI for RPG adventure extraction
class FirebaseAiService {
  final FirebaseStorageService firebaseStorageService =
      FirebaseStorageService();

  // Represents a half-open line range [start, end)
  // Used primarily for excluding the Table of Contents while matching titles.
  static const _maxTocScanLines = 1200;

  bool _looksLikeTocEntryLine(String rawLine) {
    final line = rawLine.trimRight();
    if (line.isEmpty) return false;

    // Common TOC patterns: dot leaders or trailing page numbers.
    final hasLeaders = RegExp(r'(\.{2,}|…{2,})').hasMatch(line);
    final endsWithPage = RegExp(r'\s\d{1,4}\s*$').hasMatch(line);
    final hasManySpacesBeforeNumber = RegExp(
      r'\s{2,}\d{1,4}\s*$',
    ).hasMatch(line);

    // Avoid obviously non-TOC paragraphs.
    if (line.length > 140) return false;

    return hasLeaders || hasManySpacesBeforeNumber || endsWithPage;
  }

  bool _looksLikeTocHeaderLine(String rawLine) {
    final s = _normalizeTitleForMatch(rawLine);
    if (s.isEmpty) return false;

    // Be tolerant of headings like "CONTENTS" / "Table of Contents" possibly
    // with extra words or formatting.
    if (s == 'contents' || s == 'table of contents') return true;
    if (s.contains('table of contents') && s.length <= 40) return true;
    if (s.contains('contents') && s.length <= 24) return true;
    return false;
  }

  // AI configuration
  // Use a stable, widely available model name for Firebase AI Logic.
  // Preview model names and some newer families can be location-scoped (often `global`).
  final String aiModel = 'gemini-2.5-flash';

  // Vertex AI Gemini API location.
  // `global` is safest across newer/preview model families.
  final String aiLocation = 'global';
  final String systemInstruction =
      'You are an expert at extracting RPG Adventures from text documents and producing structured data. Correct any spelling mistakes. Your task is to extract relevant details from the provided text and output it in JSON format according to the provided response schema. The definition of an RPG Adventure is: An RPG adventure is a narrative-driven scenario within a role-playing game where players guide characters through challenges and exploration to advance a storyline.';

  // Model generation parameters
  final double temperature = 1.0;
  final double topP = 0.95;
  final int topK = 40;

  String _clipTextForModel(String text) {
    // Keep prompts reliable by bounding input size.
    // Use head+tail so we keep intro/ToC and closing sections.
    const maxChars = 140000;
    const headChars = 100000;
    const tailChars = 30000;

    if (text.length <= maxChars) return text;
    final head = text.substring(0, headChars);
    final tail = text.substring(text.length - tailChars);
    return '$head\n\n[...TRUNCATED ${text.length - headChars - tailChars} CHARS...]\n\n$tail';
  }

  /// Creates a GenerativeModel with the specified schema
  GenerativeModel _createModel(
    Schema schema, {
    bool setSystemInstruction = true,
  }) {
    return FirebaseAI.vertexAI(location: aiLocation).generativeModel(
      model: aiModel,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        temperature: temperature,
        topP: topP,
        topK: topK,
      ),
      systemInstruction: setSystemInstruction
          ? Content.system(systemInstruction)
          : null,
    );
  }

  /// Analyze a single file and extract RPG adventure data
  Future<String> analyzeFile(String fileUrl, {String? runId}) async {
    try {
      // Get file from storage
      Reference fileReference = firebaseStorageService.getFileReference(
        fileUrl,
      )!;

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
        "Analyze this adventure for a role-playing game. Extract the information necessary to populate the fields in the response schema. Generate an empty string for the link field.",
      );
      final filePart = FileData(
        mimeType,
        await firebaseStorageService.getStorageUrl(fileReference),
      );

      // Emit a lightweight proof that we're sending non-empty content.
      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'ai_request_start',
          runId: runId,
          context: {
            'mode': 'fileData',
            'mimeType': mimeType,
            'storagePath': fileReference.fullPath,
            'aiModel': aiModel,
            'aiLocation': aiLocation,
          },
        ),
      );

      // Count tokens for logging
      final tokenCount = await model.countTokens([
        Content.multi([prompt, filePart]),
      ]);
      log('Token count: ${tokenCount.totalTokens}');

      // Generate content
      final response = await model.generateContent([
        Content.multi([prompt, filePart]),
      ]);

      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'ai_request_done',
          runId: runId,
          context: {
            'mode': 'fileData',
            'responseChars': (response.text ?? '').length,
          },
        ),
      );

      // Clean up: delete file after processing
      try {
        await fileReference.delete();
      } on FirebaseException catch (e) {
        // If an async pipeline already deleted the object, don't fail analysis.
        if (e.code != 'object-not-found') {
          rethrow;
        }
      }

      // Return response text
      return response.text ?? '{}';
    } catch (e) {
      // Do not return a fake JSON payload on error, because callers may
      // interpret it as a valid schema and write empty/null questCards.
      // Bubble the error up so UI can show it and avoid persisting junk docs.
      log('Error in analyzeFile (model=$aiModel location=$aiLocation): $e');
      rethrow;
    }
  }

  /// Determine if the provided file contains a single adventure or multiple adventures
  Future<Map<String, dynamic>> determineAdventureType(
    String url, {
    String? runId,
  }) async {
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
        "Determine if the file contains a single adventure or a collection of adventures. Return the type as defined in the response schema.",
      );

      String? textOverride;
      if (mimeType.startsWith('text/')) {
        try {
          final bytes = await fileReference.getData();
          if (bytes != null) {
            textOverride = utf8.decode(bytes, allowMalformed: true);
          }
        } catch (e) {
          log('determineAdventureType text download failed: $e');
        }
      }

      Map<String, dynamic> adventureType = await processAiRequest(
        typeSchema,
        mimeType,
        fileReference,
        prompt,
        textOverride: textOverride,
        runId: runId,
        telemetryStage: 'ai_determine_type_request',
      );

      log('Adventure type determined: ${adventureType.toString()}');
      return adventureType;
    } catch (e) {
      log(
        'Error in determineAdventureType (model=$aiModel location=$aiLocation): $e',
      );
      rethrow;
    }
    // We don't delete the file here as it's needed for subsequent processing
    // The calling method (autoAnalyzeFile in QuestCardAnalyze) will handle deletion
    // through analyzeSingleFile or analyzeMultiFile
  }

  /// Process multiple adventures from a single file
  Future<List<Map<String, dynamic>>> analyzeMultiFileQueries(
    String fileUrl, {
    String? runId,
  }) async {
    List<Map<String, dynamic>> allAdventures = [];
    Reference? fileReference;

    Future<List<Map<String, dynamic>>> _extractAllFromFullText(
      String mimeType,
      Reference ref,
      String fullText,
    ) async {
      // Wrap the array schema so we can reuse processAiRequest() which expects
      // an object-shaped JSON.
      final schema = Schema.object(
        properties: {'adventures': QuestCard.aiJsonSchemaMulti()},
      );

      final prompt = TextPart(
        '''Extract ALL distinct RPG adventures/scenarios contained in this document.

Return only JSON matching the response schema.

Rules:
- If the document contains 1 adventure, return an array of length 1.
- Ignore table-of-contents-only entries; prefer the full chapter/adventure content.
- Leave unknown fields as empty string, 0, or empty arrays as appropriate.
- Ensure each adventure has a non-empty title if possible; otherwise use the most specific heading-like label you can find.''',
      );

      final decoded = await processAiRequest(
        schema,
        mimeType,
        ref,
        prompt,
        textOverride: fullText,
        runId: runId,
        telemetryStage: 'ai_multi_full_extract_request',
      );

      final raw = decoded['adventures'];
      final list = (raw is List) ? raw : const [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    Future<List<Map<String, dynamic>>> _fullExtractThenEnrichAndReturn(
      String mimeType,
      Reference ref,
      String fullText,
    ) async {
      final globalInfo = await extractGlobalInformation(
        ref,
        mimeType,
        textOverride: fullText,
        runId: runId,
      );

      final purchaseLink = await _searchForPurchaseLink(globalInfo);
      if (purchaseLink != null && purchaseLink.isNotEmpty) {
        globalInfo['link'] = purchaseLink;
      }

      final extracted = await _extractAllFromFullText(mimeType, ref, fullText);

      final List<Map<String, dynamic>> enriched = [];
      for (int i = 0; i < extracted.length; i++) {
        final adv = extracted[i];

        adv['id'] = '';
        final title = (adv['title'] ?? '').toString().trim();
        if (title.isEmpty) {
          adv['title'] = 'Adventure ${i + 1}';
        }

        // Fill global fields if missing/empty.
        for (final k in <String>[
          'productTitle',
          'gameSystem',
          'publisher',
          'edition',
          'publicationYear',
          'link',
          'authors',
        ]) {
          final v = adv[k];
          final isEmptyString = v is String && v.trim().isEmpty;
          final isEmptyList = v is List && v.isEmpty;
          if (v == null || isEmptyString || isEmptyList) {
            final gv = globalInfo[k];
            if (gv != null) {
              adv[k] = gv;
            }
          }
        }

        enriched.add(adv);
      }

      return enriched;
    }

    try {
      // Get file reference and metadata
      fileReference = firebaseStorageService.getFileReference(fileUrl);
      FullMetadata metadata = await fileReference!.getMetadata();
      String? mimeType = metadata.contentType;

      if (mimeType == null) {
        throw Exception('Could not determine file mimetype');
      }

      String? fullText;
      List<String>? lines;
      if (mimeType.startsWith('text/')) {
        final downloaded = await fileReference.getData();
        if (downloaded == null || downloaded.isEmpty) {
          throw Exception('Could not download text content');
        }
        fullText = utf8.decode(downloaded, allowMalformed: true);
        lines = fullText.split(RegExp(r'\r?\n'));
        if (lines.isNotEmpty && lines.last.isEmpty) {
          lines.removeLast();
        }

        // Delete the original uploaded file as soon as we no longer need it.
        // After this point, processing happens from in-memory text.
        try {
          await fileReference.delete();
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found') {
            log('Error deleting source file: $e');
          }
        } catch (e) {
          log('Error deleting source file: $e');
        }
      }

      // 1) Determine titles first (AI), then refine via TOC parsing.
      Map<String, dynamic> titlesMap = await extractAdventureTitles(
        fileReference,
        mimeType,
        textOverride: fullText,
        runId: runId,
      );

      final List<String> aiTitles = [];
      for (final t in (titlesMap['titles'] ?? const [])) {
        if (t is Map && t['title'] != null) {
          aiTitles.add(t['title'].toString());
        }
      }

      // Detect and parse TOC if we have line data.
      final tocRange = (lines != null) ? _detectTocRange(lines) : null;
      final tocTitles = (tocRange != null && lines != null)
          ? _titlesFromToc(lines, tocRange.key, tocRange.value)
          : <String>[];

      // If TOC titles exist, prefer their order as the primary list (then merge AI titles).
      List<String> adventureTitles = aiTitles;
      if (tocTitles.length >= 5) {
        adventureTitles = _mergeUniqueTitlesPreserveOrder(tocTitles, aiTitles);
        log(
          'TOC titles parsed: ${tocTitles.length}; merged titles: ${adventureTitles.length}',
        );
      } else if (tocRange != null && lines != null && aiTitles.length < 5) {
        // If AI titles are sparse and we have a TOC section, ask AI to extract titles
        // from the TOC block only (much easier than the full doc).
        final tocText = lines.sublist(tocRange.key, tocRange.value).join('\n');
        try {
          final tocAi = await extractAdventureTitles(
            fileReference,
            mimeType,
            textOverride: tocText,
            runId: runId,
          );
          final List<String> tocAiTitles = [];
          for (final t in (tocAi['titles'] ?? const [])) {
            if (t is Map && t['title'] != null) {
              tocAiTitles.add(t['title'].toString());
            }
          }
          if (tocAiTitles.isNotEmpty) {
            adventureTitles = _mergeUniqueTitlesPreserveOrder(
              tocAiTitles,
              aiTitles,
            );
            log(
              'AI-on-TOC titles: ${tocAiTitles.length}; merged titles: ${adventureTitles.length}',
            );
          }
        } catch (e) {
          log('AI-on-TOC title extraction failed: $e');
        }
      }

      // If we still have no titles, fall back to markdown headings.
      if (adventureTitles.isEmpty) {
        try {
          final localLines = lines;
          if (localLines != null) {
            final fallback = _titlesFromMarkdownHeadings(localLines);
            if (fallback.isNotEmpty) {
              adventureTitles = fallback;
              log(
                'Fallback titles from markdown headings: ${adventureTitles.length}',
              );
            }
          }
        } catch (e) {
          log('Fallback title extraction failed: $e');
        }
      }

      // If we still have no titles, try full-document extraction.
      if (adventureTitles.isEmpty) {
        log(
          'No adventure titles found; attempting full-document multi-extract fallback.',
        );
        if (fullText == null || fullText.trim().isEmpty) {
          return [];
        }
        final enriched = await _fullExtractThenEnrichAndReturn(
          mimeType,
          fileReference,
          fullText,
        );
        log(
          'Full-document multi-extract produced ${enriched.length} adventures',
        );
        return enriched;
      }

      // 2. Extract global information applicable to all adventures
      Map<String, dynamic> globalInfo = await extractGlobalInformation(
        fileReference,
        mimeType,
        textOverride: fullText,
        runId: runId,
      );
      log("Global info extracted: ${globalInfo.keys.join(', ')}");

      var purchaseLinkFuture = _searchForPurchaseLink(globalInfo);
      String? purchaseLink = await purchaseLinkFuture;
      if (purchaseLink!.isNotEmpty) {
        globalInfo['link'] = purchaseLink;
        log('Purchase link found: ${globalInfo['link']}');
      }

      // 3. Process each individual adventure
      if (fullText == null || lines == null) {
        // Non-text inputs fall back to legacy path (download -> split -> temp uploads).
        final downloadedText = await fileReference.getData();
        if (downloadedText == null) {
          throw Exception('Could not download file data');
        }
        fullText = utf8.decode(downloadedText, allowMalformed: true);
        lines = fullText.split(RegExp(r'\r?\n'));
        if (lines.isNotEmpty && lines.last.isEmpty) {
          lines.removeLast();
        }
      }
      // --- Find Adventure Starts ---
      final adventureStarts = _findAdventureStarts(
        lines,
        adventureTitles,
        skipRange: tocRange,
      );

      // If we couldn't match most titles into body locations, fall back to full-document extraction.
      final isLongDoc = fullText.length >= 50000;
      final coverage = adventureTitles.isEmpty
          ? 0.0
          : (adventureStarts.length / adventureTitles.length);

      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'ai_multi_title_match_stats',
          runId: runId,
          context: {
            'titlesTotal': adventureTitles.length,
            'startsMatched': adventureStarts.length,
            'coverage': coverage,
            'tocDetected': tocRange != null,
            'tocTitles': tocTitles.length,
            'aiTitles': aiTitles.length,
          },
        ),
      );

      final lowCoverage = coverage < 0.4;
      if (isLongDoc && lowCoverage) {
        log(
          'Low title-to-body match coverage (${(coverage * 100).toStringAsFixed(0)}%); using full-document extraction instead.',
        );
        final enriched = await _fullExtractThenEnrichAndReturn(
          mimeType,
          fileReference,
          fullText,
        );
        log('Full-document extraction returned ${enriched.length} adventures');
        return enriched;
      }

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
          log(
            "  Warning: No content found for '$title' (start line ${startLineNum + 1} >= end line $endLineNum). Skipping.",
          );
          continue;
        }
        final adventureContentLines = lines.sublist(startLineNum, endLineNum);
        final adventureContent = adventureContentLines.join('\n');

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
                fileReference,
                mimeType,
                title,
                textOverride: adventureContent,
                runId: runId,
              );

          // Use global authors if individual authors aren't specified
          if ((individualData['authors'] ?? "").isEmpty) {
            individualData['authors'] = globalInfo['authors'] ?? "";
          }

          // Merge global and individual data
          adventureObject.addAll(individualData);
          allAdventures.add(adventureObject);
        } catch (e) {
          log("Error processing adventure '$title': $e");
        }
      }
      log("Successfully processed ${allAdventures.length} adventures");
      return allAdventures;
    } catch (e) {
      log(
        'Error in analyzeMultiFileQueries (model=$aiModel location=$aiLocation): $e',
      );
      rethrow;
    } finally {
      // Best-effort cleanup: try deleting the source file if it still exists.
      // Safe even if already deleted.
      if (fileReference != null) {
        await fileReference.delete().catchError(
          (e) => log("Error deleting source file in finally: $e"),
        );
      }
    }
  }

  /// Extract titles of all adventures in the document
  Future<Map<String, dynamic>> extractAdventureTitles(
    Reference fileReference,
    String mimeType, {
    String? textOverride,
    String? runId,
  }) async {
    Schema titleSchema = Schema.object(
      properties: {
        'titles': Schema.array(
          items: Schema.object(
            properties: {
              'title': Schema.string(
                description: 'Title of a specific adventure.',
              ),
            },
          ),
        ),
      },
    );

    TextPart prompt = TextPart('''
  Your task is to identify ALL distinct adventure scenarios contained in the provided document.

  Important:
  - Do NOT stop after finding a couple; there may be dozens.
  - If a Table of Contents exists, use it to enumerate every adventure title (in order).
  - Titles may be ALL CAPS, Title Case, or include numbers/levels (e.g., "FOUR 1ST- TO 2ND-LEVEL PCS").
  - Return only the adventure/scenario titles (not section headers like "INTRODUCTION", "CREDITS", etc.).

  Return only JSON matching the schema.
  ''');

    return await processAiRequest(
      titleSchema,
      mimeType,
      fileReference,
      prompt,
      textOverride: textOverride,
      runId: runId,
      telemetryStage: 'ai_multi_titles_request',
    );
  }

  /// Extract global information applicable to all adventures in the document
  Future<Map<String, dynamic>> extractGlobalInformation(
    Reference fileReference,
    String mimeType, {
    String? textOverride,
    String? runId,
  }) async {
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
      globalSchema,
      mimeType,
      fileReference,
      prompt,
      textOverride: textOverride,
      runId: runId,
      telemetryStage: 'ai_multi_global_request',
    );
  }

  /// Extract information specific to an individual adventure
  Future<Map<String, dynamic>> extractIndividualInformation(
    Reference fileReference,
    String mimeType,
    String title, {
    String? textOverride,
    String? runId,
  }) async {
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
      individualSchema,
      mimeType,
      fileReference,
      prompt,
      textOverride: textOverride,
      runId: runId,
      telemetryStage: 'ai_multi_individual_request',
    );
  }

  /// Generic method to make AI requests with proper error handling
  Future<Map<String, dynamic>> processAiRequest(
    Schema schema,
    String mimeType,
    Reference fileReference,
    TextPart prompt, {
    String? textOverride,
    String? runId,
    String? telemetryStage,
  }) async {
    try {
      // Check if user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        log('Error: User is not authenticated');
        return {
          'error':
              'User is not authenticated. Please sign in to access this feature.',
        };
      }

      GenerativeModel requestModel = _createModel(schema);

      final bool useInlineText =
          (textOverride != null && textOverride.isNotEmpty);
      final String? clippedText = useInlineText
          ? _clipTextForModel(textOverride)
          : null;

      Map<String, dynamic> _textStats(String text) {
        final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        final first = normalized.isEmpty
            ? ''
            : normalized.substring(0, normalized.length.clamp(0, 80));
        final headings = RegExp(
          r'^#+\s+.+',
          multiLine: true,
        ).allMatches(text).length;
        final digest = sha256.convert(utf8.encode(text)).toString();
        return {
          'chars': text.length,
          'lines': RegExp(r'\r?\n').allMatches(text).length + 1,
          'headingCount': headings,
          'sha256': digest,
          'preview80': first,
        };
      }

      // Prefer inline text for text/* inputs so the model definitely receives content.
      // This avoids relying on the model fetching Storage URLs.
      final List<Part> parts;
      if (useInlineText) {
        parts = [prompt, TextPart(clippedText!)];

        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: telemetryStage ?? 'ai_request_start',
            runId: runId,
            context: {
              'mode': 'inlineText',
              'mimeType': mimeType,
              'storagePath': fileReference.fullPath,
              'aiModel': aiModel,
              'aiLocation': aiLocation,
              'text': _textStats(clippedText),
            },
          ),
        );
      } else {
        // Get an authenticated URL for the file
        String fileUrl = await firebaseStorageService.getStorageUrl(
          fileReference,
        );
        // Avoid logging the full signed URL; use Storage path instead.
        log(
          'Using FileData for AI request (mimeType=$mimeType path=${fileReference.fullPath})',
        );

        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: telemetryStage ?? 'ai_request_start',
            runId: runId,
            context: {
              'mode': 'fileData',
              'mimeType': mimeType,
              'storagePath': fileReference.fullPath,
              'aiModel': aiModel,
              'aiLocation': aiLocation,
              // We include a stable identifier (path) without the tokenized URL.
              'fileData': {'urlHost': Uri.tryParse(fileUrl)?.host},
            },
          ),
        );

        // Create file part for the model
        parts = [prompt, FileData(mimeType, fileUrl)];
      }

      try {
        // Get token counts for monitoring/logging
        var tokenCount = await requestModel.countTokens([Content.multi(parts)]);

        log('Token count: ${tokenCount.totalTokens}');
      } catch (tokenCountError) {
        // Continue even if token counting fails
        log('Warning: Failed to count tokens: $tokenCountError');
      }

      // Make the actual API request
      var response = await requestModel.generateContent([Content.multi(parts)]);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from AI model');
      }

      final decoded = jsonDecode(response.text!);

      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: (telemetryStage ?? 'ai_request') + '_done',
          runId: runId,
          context: {
            'responseChars': response.text!.length,
            'decodedType': decoded.runtimeType.toString(),
          },
        ),
      );

      return decoded;
    } catch (e) {
      log(
        'Error in AI request processing (model=$aiModel location=$aiLocation): $e',
      );

      // Best-effort: emit request-failure telemetry with just sizes (no content).
      ClientTelemetryService.emit(
        ClientTelemetryService.error(
          stage: (telemetryStage ?? 'ai_request') + '_error',
          runId: runId,
          message: 'AI request failed',
          error: e,
          context: {
            'mode': (textOverride != null && textOverride.isNotEmpty)
                ? 'inlineText'
                : 'fileData',
            'mimeType': mimeType,
            'storagePath': fileReference.fullPath,
          },
        ),
      );

      if (e.toString().contains('permission')) {
        log(
          'Permission error details: This may be due to insufficient Firebase permissions.',
        );
        final email =
            FirebaseAuth.instance.currentUser?.email ?? 'Not signed in';
        log('Current user email: $email');
      }
      rethrow;
    }
  }

  // --- Helper Function to Find Adventure Start Lines ---
  MapEntry<int, int>? _detectTocRange(List<String> lines) {
    // Heuristic: find a "Contents" / "Table of Contents" header, then capture
    // the following block until we hit enough consecutive non-TOC-looking lines.
    int? tocStart;

    for (int i = 0; i < lines.length && i < _maxTocScanLines; i++) {
      if (_looksLikeTocHeaderLine(lines[i])) {
        tocStart = i;
        break;
      }
    }

    if (tocStart == null) return null;

    int end = tocStart + 1;
    int misses = 0;

    for (
      int i = tocStart + 1;
      i < lines.length && i < tocStart + 1 + _maxTocScanLines;
      i++
    ) {
      final line = lines[i];
      if (_looksLikeTocEntryLine(line)) {
        end = i + 1;
        misses = 0;
        continue;
      }

      // Allow a few non-matching lines (e.g., section headers / blank lines)
      // but stop when the block clearly ends.
      if (line.trim().isEmpty) {
        misses++;
      } else {
        misses++;
      }

      if (misses >= 12) {
        break;
      }
    }

    // Minimum size check.
    if (end - tocStart < 8) return null;
    return MapEntry(tocStart, end);
  }

  List<String> _titlesFromToc(
    List<String> lines,
    int tocStart,
    int tocEndExclusive, {
    int maxTitles = 120,
  }) {
    final titles = <String>[];
    final seen = <String>{};

    String? extractTitle(String raw) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) return null;

      // Examples handled:
      // - "The Black Keep .......... 12"
      // - "1. The Black Keep 12"
      // - "CHAPTER 3: The Black Keep   12"
      final leaderMatch = RegExp(
        r'^\s*(?:\d+[\.)]\s*)?(.+?)\s*(?:\.{2,}|…{2,})\s*\d{1,4}\s*$',
      ).firstMatch(line);
      if (leaderMatch != null) {
        return leaderMatch.group(1)?.trim();
      }

      final pageMatch = RegExp(
        r'^\s*(?:\d+[\.)]\s*)?(.+?)\s{2,}\d{1,4}\s*$',
      ).firstMatch(line);
      if (pageMatch != null) {
        return pageMatch.group(1)?.trim();
      }

      return null;
    }

    bool isGeneric(String normalized) {
      return {
        'contents',
        'table of contents',
        'introduction',
        'credits',
        'appendix',
        'index',
      }.contains(normalized);
    }

    for (int i = tocStart; i < tocEndExclusive && i < lines.length; i++) {
      final candidate = extractTitle(lines[i]);
      if (candidate == null || candidate.isEmpty) continue;

      final normalized = _normalizeTitleForMatch(candidate);
      if (normalized.isEmpty) continue;
      if (normalized.length < 4 || normalized.length > 90) continue;
      if (isGeneric(normalized)) continue;

      if (seen.add(normalized)) {
        titles.add(candidate);
        if (titles.length >= maxTitles) break;
      }
    }

    return titles;
  }

  List<String> _mergeUniqueTitlesPreserveOrder(
    List<String> primary,
    List<String> secondary,
  ) {
    final out = <String>[];
    final seen = <String>{};

    void addAll(List<String> titles) {
      for (final t in titles) {
        final n = _normalizeTitleForMatch(t);
        if (n.isEmpty) continue;
        if (seen.add(n)) {
          out.add(t);
        }
      }
    }

    addAll(primary);
    addAll(secondary);
    return out;
  }

  String _normalizeTitleForMatch(String input) {
    var s = input.trim().toLowerCase();

    // Strip common markdown/prefix characters (headings, blockquotes, list bullets).
    s = s.replaceAll(RegExp(r'^[\s#>*\-–—]+'), '');

    // Strip simple numbering prefixes: "1.", "1)", "[1]", etc.
    s = s.replaceAll(RegExp(r'^(\[\d+\]|\(?\d+\)?[\.)\]]?)\s+'), '');

    // Remove emphasis/code markers.
    s = s.replaceAll(RegExp(r'[`*_~]+'), '');

    // Collapse whitespace.
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  List<String> _titlesFromMarkdownHeadings(
    List<String> lines, {
    int maxTitles = 30,
  }) {
    final titles = <String>[];
    final seen = <String>{};

    for (final line in lines) {
      final raw = line.trim();
      if (!raw.startsWith('#')) continue;

      // Remove leading heading markers.
      final candidate = raw.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      final normalized = _normalizeTitleForMatch(candidate);
      if (normalized.isEmpty) continue;

      // Heuristic: avoid headings that are too short/long or obviously generic.
      if (normalized.length < 4 || normalized.length > 80) continue;
      if ({
        'contents',
        'table of contents',
        'introduction',
        'credits',
        'appendix',
      }.contains(normalized)) {
        continue;
      }

      if (seen.add(normalized)) {
        titles.add(candidate);
        if (titles.length >= maxTitles) break;
      }
    }

    return titles;
  }

  List<MapEntry<int, String>> _findAdventureStarts(
    List<String> lines,
    List<String> adventureTitles, {
    MapEntry<int, int>? skipRange,
  }) {
    final int skipStart = skipRange?.key ?? -1;
    final int skipEnd = skipRange?.value ?? -1;

    bool isSkippedLine(int i) {
      return skipRange != null && i >= skipStart && i < skipEnd;
    }

    bool looksHeadingLike(String raw) {
      final s = raw.trim();
      if (s.isEmpty) return false;
      if (s.length > 110) return false;
      // Headings usually do not end with a period.
      if (s.endsWith('.')) return false;
      // TOC entries are not headings.
      if (_looksLikeTocEntryLine(s)) return false;
      // Markdown headings or all-caps lines are strong signals.
      if (s.startsWith('#')) return true;

      // Require fairly heading-ish shape: not too many words.
      final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (words > 14) return false;

      final letters = RegExp(r'[a-zA-Z]').allMatches(s).length;
      if (letters >= 6) {
        final upper = RegExp(r'[A-Z]').allMatches(s).length;
        if (upper / letters >= 0.7) return true;
      }

      // Title Case-ish: multiple words, most start with uppercase.
      final capped = RegExp(r'\b[A-Z][a-z]').allMatches(s).length;
      if (words >= 2 && capped / words >= 0.6) return true;

      // Otherwise it's not reliably a heading.
      return false;
    }

    // For each title, find best matching line index.
    final potentialStarts = <MapEntry<int, String>>[];
    final notFound = <String>[];

    log('Scanning file for titles (skip TOC=${skipRange != null})...');

    for (final originalTitle in adventureTitles) {
      final normalizedTitle = _normalizeTitleForMatch(originalTitle);
      if (normalizedTitle.isEmpty) {
        notFound.add(originalTitle);
        continue;
      }

      int? bestLine;
      int bestScore = -1;

      for (int i = 0; i < lines.length; i++) {
        if (isSkippedLine(i)) continue;
        final rawLine = lines[i];

        // Even if we didn't detect the TOC header, never treat a TOC-looking
        // line as an adventure start. This is the primary defense against
        // creating empty cards from TOC-only content.
        if (_looksLikeTocEntryLine(rawLine)) continue;

        final normalizedLine = _normalizeTitleForMatch(rawLine);
        if (normalizedLine.isEmpty) continue;

        int score = -1;

        if (normalizedLine == normalizedTitle) {
          score = 5;
        } else if (normalizedLine.contains(normalizedTitle) &&
            normalizedTitle.length >= 6) {
          // Only accept partial matches when the line looks like a heading.
          if (looksHeadingLike(rawLine)) {
            score = 3;
          }
        } else {
          // Token overlap fallback (helps when OCR inserts punctuation).
          final tTokens = normalizedTitle.split(' ').where((t) => t.isNotEmpty);
          final lTokens = normalizedLine.split(' ').where((t) => t.isNotEmpty);
          final tSet = tTokens.toSet();
          if (tSet.isNotEmpty) {
            int overlap = 0;
            for (final tok in lTokens) {
              if (tSet.contains(tok)) overlap++;
            }
            final ratio = overlap / tSet.length;
            if (looksHeadingLike(rawLine)) {
              if (ratio >= 0.75 && tSet.length >= 3) {
                score = 2;
              } else if (ratio >= 0.9 && tSet.length == 2) {
                score = 2;
              }
            }
          }
        }

        if (score < 0) continue;

        if (looksHeadingLike(rawLine)) {
          score += 1;
        }

        // Prefer later matches on ties (TOC is usually earlier than body).
        if (score > bestScore ||
            (score == bestScore && bestLine != null && i > bestLine)) {
          bestScore = score;
          bestLine = i;
        }
      }

      if (bestLine == null) {
        notFound.add(originalTitle);
        continue;
      }

      potentialStarts.add(MapEntry(bestLine, originalTitle));
    }

    if (notFound.isNotEmpty) {
      // Keep the log small; the telemetry already contains the full title list.
      log('WARNING: ${notFound.length} titles not found in body text.');
    }

    if (potentialStarts.isEmpty) {
      log('ERROR: No adventure titles could be matched to body text.');
      return [];
    }

    // Sort and dedupe by line number (if multiple titles map to same line, keep the first).
    potentialStarts.sort((a, b) => a.key.compareTo(b.key));
    final deduped = <MapEntry<int, String>>[];
    final usedLines = <int>{};
    for (final e in potentialStarts) {
      if (usedLines.add(e.key)) {
        deduped.add(e);
      }
    }

    log('Identified adventure start points (sorted): ${deduped.length}');
    for (final entry in deduped.take(12)) {
      log('  Line ${entry.key + 1}: ${entry.value}');
    }

    return deduped;
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
    Map<String, dynamic> metadata,
  ) async {
    final purchaseLinkService = PurchaseLinkService();
    try {
      return await purchaseLinkService.findPurchaseLink(metadata);
    } finally {
      purchaseLinkService.dispose();
    }
  }
}
