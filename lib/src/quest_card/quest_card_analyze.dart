import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:async';
// Import needed for WriteBatch
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:quest_cards/src/services/email_service.dart';
import 'package:quest_cards/src/services/firebase_functions_service.dart';
import 'package:quest_cards/src/services/firebase_storage_service.dart';
import 'package:quest_cards/src/services/purchase_link_service.dart';
import 'package:quest_cards/src/services/client_telemetry_service.dart';
// cloud_firestore import not required here

import '../services/firebase_auth_service.dart';
import '../services/firebase_ai_service.dart';
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

  String? _runId;
  String? _stage;

  String? _pdfToMdJobId;
  String? _pdfToMdStatus;
  String? _pdfToMdError;

  String _newRunId() {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    int rand;
    try {
      rand = math.Random.secure().nextInt(0x7fffffff);
    } catch (_) {
      rand = math.Random().nextInt(0x7fffffff);
    }
    return '${micros}_${rand.toRadixString(16)}';
  }

  final FirebaseStorageService firebaseStorageService =
      FirebaseStorageService();
  final FirebaseAiService aiService = FirebaseAiService();
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();
  final EmailService emailService = EmailService();
  final FirebaseFunctionsService functionsService = FirebaseFunctionsService();

  void _showPersistentErrorSnackBar(Object error) {
    if (!mounted) return;
    final message = 'Error analyzing file: ${error.toString()}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 12),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: message));
          },
        ),
      ),
    );
  }

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
        'json',
      ],
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
              onPressed: _isAnalyzing
                  ? null
                  : _pickFile, // Disable while analyzing
              child: Text('Pick a File'),
            ),
            SizedBox(height: 20),
            if (_isAnalyzing)
              _buildProgressUi() // Show indicator + detailed status when analyzing
            else
              ElevatedButton(
                // Disable button if no file is selected or already analyzing
                onPressed: _file == null || _isAnalyzing
                    ? null
                    : _handleAnalysis,
                child: Text('Analyze File'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressUi() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Converting PDF to Markdown',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              if (_stage != null) Text('Stage: ${_stage!}'),
              if (_runId != null)
                Text(
                  'Run: ${_runId!}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              if (_pdfToMdStatus != null) Text('Status: ${_pdfToMdStatus!}'),
              if (_pdfToMdJobId != null)
                Text(
                  'Job: ${_pdfToMdJobId!}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              if (_pdfToMdError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _pdfToMdError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final payload = <String, dynamic>{
                        'runId': _runId,
                        'stage': _stage,
                        'jobId': _pdfToMdJobId,
                        'pdfToMdStatus': _pdfToMdStatus,
                        'pdfToMdError': _pdfToMdError,
                        'filename': _file?.name,
                        'size': _file?.size,
                      };
                      await Clipboard.setData(
                        ClipboardData(text: jsonEncode(payload)),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Debug info copied.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy debug info'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _humanizePdfJobStatus(String raw) {
    switch (raw) {
      case 'creating':
        return 'Creating job…';
      case 'uploading':
        return 'Uploading PDF…';
      case 'queued':
        return 'Queued…';
      case 'processing':
        return 'Processing…';
      case 'done':
        return 'Done';
      case 'failed':
        return 'Failed';
      default:
        return raw;
    }
  }

  Future<void> _handleAnalysis() async {
    if (_file == null) return;

    setState(() {
      _isAnalyzing = true; // Start loading indicator
      _runId = _newRunId();
      _stage = 'starting';
      _pdfToMdJobId = null;
      _pdfToMdStatus = null;
      _pdfToMdError = null;
    });

    // Best-effort start marker.
    ClientTelemetryService.emit(
      ClientTelemetryService.event(
        stage: 'analyze_start',
        runId: _runId,
        message: 'User started analysis',
        context: {'filename': _file?.name, 'size': _file?.size},
      ),
    );

    try {
      List<String> resultingDocIds = await autoAnalyzeFile();
      // Navigate only after analysis is complete
      if (mounted) {
        // Check if the widget is still in the tree
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                QuestCardListView(questCardList: resultingDocIds),
          ),
        );
      }
    } catch (e) {
      log("Error during analysis: $e");
      ClientTelemetryService.emit(
        ClientTelemetryService.error(
          stage: 'handleAnalysis',
          runId: _runId,
          message: 'Top-level analyze handler failed',
          error: e,
        ),
      );
      _showPersistentErrorSnackBar(e);
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
      if (mounted) {
        setState(() => _stage = 'detecting_file_type');
      }
      // Upload the file (or its converted content) ONCE
      var mimeType = lookupMimeType(_file!.name);
      log('File MIME type: ${mimeType ?? 'unknown'}');

      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'mime_detected',
          runId: _runId,
          context: {
            'mimeType': mimeType,
            'filename': _file?.name,
            'size': _file?.size,
          },
        ),
      );

      if (mimeType == 'application/pdf') {
        log('Converting PDF to Markdown...');
        if (mounted) {
          setState(() => _stage = 'pdf_to_md');
        }
        ClientTelemetryService.emit(
          ClientTelemetryService.event(stage: 'pdf_to_md_start', runId: _runId),
        );
        url = await functionsService.pdfToMarkdownUrl(
          _file!,
          runId: _runId,
          onJobId: (id) {
            if (!mounted) return;
            setState(() => _pdfToMdJobId = id);
            ClientTelemetryService.emit(
              ClientTelemetryService.event(
                stage: 'pdf_to_md_job_created',
                runId: _runId,
                context: {'jobId': id},
              ),
            );
          },
          onStatusChanged: (s) {
            if (!mounted) return;
            setState(() => _pdfToMdStatus = _humanizePdfJobStatus(s));
            ClientTelemetryService.emit(
              ClientTelemetryService.event(
                stage: 'pdf_to_md_status',
                runId: _runId,
                context: {'status': s, 'jobId': _pdfToMdJobId},
              ),
            );
          },
        );
        log('Generated Markdown uploaded to: $url');
        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: 'pdf_to_md_done',
            runId: _runId,
            context: {'jobId': _pdfToMdJobId, 'mdUrl': url},
          ),
        );
      } else if (mimeType != null && mimeType.startsWith('text/')) {
        log('Uploading text file...');
        if (mounted) {
          setState(() => _stage = 'uploading_text');
        }
        // Assuming uploadFile handles PlatformFile directly for text
        url = await firebaseStorageService.uploadFile(_file!);
      } else {
        // Handle other file types if necessary, or treat as generic upload
        log('Uploading generic file...');
        if (mounted) {
          setState(() => _stage = 'uploading_generic');
        }
        url = await firebaseStorageService.uploadFile(_file!);
      }
      log('File uploaded to: $url');

      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'file_uploaded',
          runId: _runId,
          context: {'url': url, 'mimeType': mimeType, 'filename': _file?.name},
        ),
      );

      // Analyze the file using AI service to determine contents
      log('Determining adventure type...');
      if (mounted) {
        setState(() => _stage = 'ai_determine_type');
      }
      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'ai_determine_type_start',
          runId: _runId,
          context: {
            'fileUrl': url,
            'mimeType': mimeType,
            'filename': _file?.name,
            'size': _file?.size,
            'aiModel': aiService.aiModel,
            'aiLocation': aiService.aiLocation,
          },
        ),
      );
        Map<String, dynamic> adventureTypeResult = await aiService
          .determineAdventureType(url, runId: _runId);
      String adventureType = (adventureTypeResult['adventureType'] ?? '')
          .toString()
          .trim();

      if (adventureType.isEmpty) {
        throw Exception(
          'Could not determine adventure type (empty AI response).',
        );
      }
      log('Determined adventure type: $adventureType');

      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'ai_determine_type_done',
          runId: _runId,
          context: {'adventureType': adventureType},
        ),
      );

      // Call the appropriate analysis function, passing the URL
      List<String> resultDocIds;
      if (adventureType == 'Single') {
        if (mounted) {
          setState(() => _stage = 'ai_analyze_single');
        }
        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: 'ai_analyze_single_start',
            runId: _runId,
          ),
        );
        resultDocIds = await analyzeSingleFile(url); // Pass URL
        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: 'ai_analyze_single_done',
            runId: _runId,
            context: {'docIds': resultDocIds},
          ),
        );
      } else {
        // Assume 'Multi' or default to multi-processing
        if (mounted) {
          setState(() => _stage = 'ai_analyze_multi');
        }
        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: 'ai_analyze_multi_start',
            runId: _runId,
            context: {
              'fileUrl': url,
              'mimeType': mimeType,
              'filename': _file?.name,
              'size': _file?.size,
              'pdfToMdJobId': _pdfToMdJobId,
              'pdfToMdStatus': _pdfToMdStatus,
              'aiModel': aiService.aiModel,
              'aiLocation': aiService.aiLocation,
            },
          ),
        );
        resultDocIds = await analyzeMultiFile(url); // Pass URL
        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: 'ai_analyze_multi_done',
            runId: _runId,
            context: {'docIds': resultDocIds},
          ),
        );
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

      final failedStage = _stage;

      if (mounted) {
        setState(() => _stage = 'failed');
      }

      // Best-effort: report the failure to Cloud Logs via a callable.
      // This helps debugging when Firestore requests are blocked in the browser
      // (e.g., net::ERR_BLOCKED_BY_CLIENT) and no server logs are produced.
      try {
        await ClientTelemetryService.error(
          stage: 'autoAnalyzeFile',
          runId: _runId,
          message: 'Analyze failed (client-side)',
          error: e,
          stackTrace: s,
          context: {
            'fileUrl': url,
            'pdfToMdJobId': _pdfToMdJobId,
            'pdfToMdStatus': _pdfToMdStatus,
            'pdfToMdError': _pdfToMdError,
            'stage': failedStage,
          },
        );
      } catch (reportError) {
        log('Failed to report client error: $reportError');
      }

      if (mounted) {
        setState(() {
          _pdfToMdError = e.toString();
        });
      }

      // Attempt to delete the file even if analysis failed
      if (url != null) {
        try {
          log('Deleting uploaded file after error...');
          bool success = await firebaseStorageService.deleteFile(url);
          if (success) {
            log('File deleted successfully.');
          } else {
            log(
              'Failed to delete file after error. It may not exist or you may not have permission.',
            );
          }
        } catch (deleteError) {
          log('Exception while trying to delete file: $deleteError');
          // We don't rethrow here to avoid masking the original error
        }
      }

      rethrow; // Rethrow the original exception after logging
    }
  }

  Future<List<String>> analyzeSingleFile(String fileUrl) async {
    log("Analyze single quest file from URL: $fileUrl");
    try {
      // Start AI metadata extraction
      log('Calling AI service for single file analysis...');
      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'ai_single_generate_start',
          runId: _runId,
          context: {'fileUrl': fileUrl},
        ),
      );
      var metadataFuture = aiService.analyzeFile(fileUrl, runId: _runId);

      // Wait for the AI service to complete metadata extraction
      Map<String, dynamic> questCardSchema = jsonDecode(await metadataFuture);
      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'ai_single_generate_done',
          runId: _runId,
          context: {
            'keys': questCardSchema.keys.toList(),
            'title': (questCardSchema['title'] ?? '').toString(),
          },
        ),
      );

      // Guard against partial/empty results to avoid writing junk docs.
      final title = (questCardSchema['title'] ?? '').toString().trim();
      final summary = (questCardSchema['summary'] ?? '').toString().trim();
      if (title.isEmpty || summary.isEmpty) {
        throw Exception(
          'AI extraction returned an empty result (missing title/summary).',
        );
      }
      var purchaseLinkFuture = _searchForPurchaseLink(questCardSchema);
      QuestCard questCard = QuestCard.fromJson(questCardSchema);

      // Set uploader information
      final currentUser = auth.getCurrentUser();
      if (currentUser != null) {
        questCard.uploadedBy = currentUser.uid;
        questCard.uploaderEmail = currentUser.email;
        questCard.uploadedTimestamp = DateTime.now();
        log(
          'Set uploader info: UID - ${currentUser.uid}, Email - ${currentUser.email}',
        );
      } else {
        log('Error: Current user is null, cannot set uploader information.');
        // Handle cases where user might not be available, though this should ideally not happen here
        // For example, by throwing an error or setting default/anonymous values if appropriate
      }

      log('AI analysis complete. Title: ${questCard.title}');

      // If productTitle is blank, set it to title
      if (questCard.productTitle == null ||
          questCard.productTitle!.trim().isEmpty) {
        questCard.productTitle = questCard.title;
        log(
          'Product title was blank after AI analysis, set to title: ${questCard.title}',
        );
      }

      // Wait for purchase link search to complete and add to QuestCard if found
      String? purchaseLink = await purchaseLinkFuture;
      if (purchaseLink != null && purchaseLink.isNotEmpty) {
        questCard.link = purchaseLink;
        log('Purchase link found: ${questCard.link}');
      }

      // Check for duplicates
      log('Checking for duplicate title: ${questCard.title}');
      String? dupeId = await firestoreService.getQuestByTitle(
        questCard.title ?? '',
      );

      if (dupeId != null) {
        // A duplicate is found
        log(
          "Duplicate found: $dupeId for title '${questCard.title}'. Returning existing ID.",
        );
        return [dupeId];
      } else {
        log("No duplicate found for title '${questCard.title}'.");
        // Check classification
        if (questCard.classification != 'Adventure') {
          log(
            'Classification is not Adventure (${questCard.classification}). Sending notification.',
          );
          // AI has determined it is not an adventure, send an email to admin
          emailService.sendNonAdventureEmailToAdmin(
            questCard.toJson().toString(),
          );
        }

        // No duplicate found, add the new quest card
        log('Adding new quest card to Firestore...');
        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: 'firestore_add_quest_start',
            runId: _runId,
            context: {
              'title': questCard.title,
              'uploaderUid': auth.getCurrentUser()?.uid,
            },
          ),
        );
        String docId = await firestoreService.addQuestCard(questCard);
        log('New quest card added with ID: $docId');
        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: 'firestore_add_quest_done',
            runId: _runId,
            context: {'docId': docId},
          ),
        );
        return [docId];
      }
    } catch (e, s) {
      log("Error in analyzeSingleFile: $e");
      log("Stacktrace: $s");
      ClientTelemetryService.emit(
        ClientTelemetryService.error(
          stage: 'analyzeSingleFile',
          runId: _runId,
          message: 'Single-file analysis failed',
          error: e,
          stackTrace: s,
          context: {'fileUrl': fileUrl},
        ),
      );
      rethrow; // Rethrow the exception after logging
    }
  }

  Future<List<String>> analyzeMultiFile(String fileUrl) async {
    log("Analyze multiple quest file from URL: $fileUrl");
    List<String> resultingDocIds = [];
    List<QuestCard> cardsToAdd = [];
    List<Map<String, dynamic>> nonAdventureCardsData = [];

    try {
      // REMOVED redundant file upload

      // Analyze the file using AI service
      log('Calling AI service for multi-file analysis...');
      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'ai_multi_generate_start',
          runId: _runId,
          context: {
            'fileUrl': fileUrl,
            'aiModel': aiService.aiModel,
            'aiLocation': aiService.aiLocation,
          },
        ),
      );
        List<Map<String, dynamic>> questCardSchemas = await aiService
          .analyzeMultiFileQueries(fileUrl, runId: _runId); // Use passed URL
      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'ai_multi_generate_done',
          runId: _runId,
          context: {
            'count': questCardSchemas.length,
            'titles': questCardSchemas
                .map((e) => (e['title'] ?? '').toString())
                .where((t) => t.trim().isNotEmpty)
                .take(10)
                .toList(),
          },
        ),
      );

      if (questCardSchemas.isEmpty) {
        // Best-effort: emit a small debug signal about the markdown contents.
        try {
          final ref = firebaseStorageService.getFileReference(fileUrl);
          final meta = await ref?.getMetadata();
          final previewBytes = await ref?.getData(256 * 1024);
          final previewText = previewBytes == null
              ? ''
              : utf8.decode(previewBytes, allowMalformed: true);
          final headingCount = RegExp(
            r'^#+\s+.+',
            multiLine: true,
          ).allMatches(previewText).length;
          ClientTelemetryService.emit(
            ClientTelemetryService.event(
              stage: 'ai_multi_zero_results',
              runId: _runId,
              context: {
                'fileUrl': fileUrl,
                'contentType': meta?.contentType,
                'size': meta?.size,
                'previewChars': previewText.length,
                'headingCount': headingCount,
              },
            ),
          );
        } catch (_) {
          // Ignore debug failures.
        }

        throw Exception(
          'AI multi extraction returned 0 adventures. This usually means the Markdown had no detectable adventure headings/titles (or the model was given an empty/unsupported input).',
        );
      }

      // --- Batch Duplicate Check ---
      List<String> titlesToCheck = questCardSchemas
          .map((schema) => (schema['title'] as String?)?.toLowerCase())
          .where((title) => title != null && title.isNotEmpty)
          .toList()
          .cast<String>(); // Ensure non-null, non-empty titles

      log('Checking ${titlesToCheck.length} titles for duplicates...');
      Map<String, String> existingTitles = await firestoreService
          .getQuestsByTitles(titlesToCheck);
      log('Found ${existingTitles.length} existing titles.');
      ClientTelemetryService.emit(
        ClientTelemetryService.event(
          stage: 'multi_duplicate_check_done',
          runId: _runId,
          context: {
            'candidates': titlesToCheck.length,
            'duplicates': existingTitles.length,
          },
        ),
      );
      // --- End Batch Duplicate Check ---

      final currentUser = auth.getCurrentUser();
      String? currentUserId;
      String? currentUserEmail;

      if (currentUser != null) {
        currentUserId = currentUser.uid;
        currentUserEmail = currentUser.email;
        log(
          'Current user for multi-file: UID - $currentUserId, Email - $currentUserEmail',
        );
      } else {
        log(
          'Error: Current user is null for multi-file analysis. UploadedBy and uploaderEmail will be null.',
        );
        // Decide how to handle this - throw error, or allow anonymous if your model supports it
      }

      // Process results: identify duplicates and prepare new cards
      for (int i = 0; i < questCardSchemas.length; i++) {
        QuestCard q = QuestCard.fromJson(questCardSchemas[i]);

        // Set uploader information
        q.uploadedBy = currentUserId;
        q.uploaderEmail = currentUserEmail;
        q.uploadedTimestamp = DateTime.now();

        // If productTitle is blank, set it to title
        if (q.productTitle == null || q.productTitle!.trim().isEmpty) {
          q.productTitle = q.title;
          log(
            'Product title was blank after AI analysis for multi-file, set to title: ${q.title}',
          );
        }

        String? titleLower = q.title?.toLowerCase();

        if (titleLower != null && existingTitles.containsKey(titleLower)) {
          // Duplicate found
          String dupeId = existingTitles[titleLower]!;
          log(
            "Duplicate found: $dupeId for title '${q.title}'. Adding existing ID.",
          );
          resultingDocIds.add(dupeId);
        } else {
          log("No duplicate found for title '${q.title}'. Preparing to add.");
          // Not a duplicate, prepare for batch write
          cardsToAdd.add(q);
          // Check classification for potential email notification
          if (q.classification != 'Adventure') {
            log(
              "Classification is not Adventure (${q.classification}) for title '${q.title}'. Queuing notification.",
            );
            nonAdventureCardsData.add(
              q.toJson(),
            ); // Store data for potential batched email
          }
        }
      }

      // --- Batch Write ---
      if (cardsToAdd.isNotEmpty) {
        log('Adding ${cardsToAdd.length} new quest cards in a batch...');
        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: 'firestore_add_multiple_start',
            runId: _runId,
            context: {'count': cardsToAdd.length},
          ),
        );
        List<String> newDocIds = await firestoreService.addMultipleQuestCards(
          cardsToAdd,
        );
        resultingDocIds.addAll(newDocIds);
        log('Batch write complete. Added IDs: $newDocIds');
        ClientTelemetryService.emit(
          ClientTelemetryService.event(
            stage: 'firestore_add_multiple_done',
            runId: _runId,
            context: {
              'added': newDocIds.length,
              'docIds': newDocIds.take(10).toList(),
            },
          ),
        );
      }
      // --- End Batch Write ---

      // --- Handle Non-Adventure Notifications ---
      if (nonAdventureCardsData.isNotEmpty) {
        log(
          'Sending notifications for ${nonAdventureCardsData.length} non-adventure items...',
        );
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
      ClientTelemetryService.emit(
        ClientTelemetryService.error(
          stage: 'analyzeMultiFile',
          runId: _runId,
          message: 'Multi-file analysis failed',
          error: e,
          stackTrace: s,
          context: {'fileUrl': fileUrl},
        ),
      );
      rethrow; // Rethrow the exception after logging
    }
  }

  /// Extracts basic metadata for search from a file
  // Future<Map<String, String>> _extractBasicMetadataForSearch(
  //     String fileUrl) async {
  //   try {
  //     // Use a simplified AI request to extract just title, publisher, and game system
  //     log('Extracting basic metadata for search');

  //     // Check if fileUrl is a storage path or a download URL
  //     String fileNameToUse;
  //     if (fileUrl.startsWith('http')) {
  //       // For download URLs
  //       final uri = Uri.parse(fileUrl);
  //       final pathSegments = uri.pathSegments;
  //       if (pathSegments.isNotEmpty) {
  //         fileNameToUse = pathSegments.last;
  //         // Handle Firebase Storage URL encoding
  //         if (fileNameToUse.contains('%2F')) {
  //           fileNameToUse = Uri.decodeComponent(fileNameToUse);
  //         }
  //       } else {
  //         fileNameToUse = 'unknown';
  //       }
  //     } else if (fileUrl.contains('/')) {
  //       // For storage paths like 'uploads/filename.txt'
  //       final segments = fileUrl.split('/');
  //       fileNameToUse = segments.last;
  //     } else {
  //       // Fallback
  //       fileNameToUse = fileUrl;
  //     }

  //     // Remove file extension if present
  //     final fileNameWithoutExtension = fileNameToUse.split('.').first;

  //     // For QC prefixed filenames, strip that prefix
  //     final cleanName = fileNameWithoutExtension.startsWith('QC')
  //         ? fileNameWithoutExtension.substring(2)
  //         : fileNameWithoutExtension;

  //     return {
  //       'title': cleanName,
  //       'publisher': '',
  //       'gameSystem': '',
  //     };
  //   } catch (e) {
  //     log('Error extracting basic metadata: $e');
  //     return {
  //       'title': '',
  //       'publisher': '',
  //       'gameSystem': '',
  //     };
  //   }
  // }

  /// Searches for a purchase link based on metadata
  Future<String?> _searchForPurchaseLink(Map<String, dynamic> metadata) async {
    if (metadata['productTitle']?.isEmpty ?? true) {
      log('No product title in metadata, skipping purchase link search');
      return null;
    }

    try {
      log('Searching for purchase link for ${metadata['productTitle']}');
      log(
        'Search metadata: ${metadata['publisher'] ?? 'unknown publisher'}, ${metadata['gameSystem'] ?? 'unknown system'}',
      );

      // Run in a separate isolate to avoid blocking the main thread
      var result = await compute(_isolatedPurchaseLinkSearch, metadata);

      if (result == null) {
        log('No purchase link found for ${metadata['productTitle']}');
      } else {
        log('Purchase link found: $result');
      }

      return result;
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

  Future<List<String>> callTestFunction(String s) async {
    log("Calling test function");
    List<String> results = [];
    try {
      var x = await FirebaseFunctions.instance
          .httpsCallable('on_call_example')
          .call({'text': s});

      results.add(x.data.toString());
      log("Results: $results");
      return results;
    } catch (e) {
      log("Error in testFunction: $e");
      rethrow; // Rethrow the exception after logging
    }
  }
}
