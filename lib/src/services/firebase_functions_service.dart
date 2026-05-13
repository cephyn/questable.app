import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'firebase_storage_service.dart';

class FirebaseFunctionsService {
  final FirebaseStorageService firebaseStorageService =
      FirebaseStorageService();

  static const String _pdfToMdJobsCollection = 'pdfToMdJobs';

  // Future<String> pdfToText(PlatformFile platformFile) async {
  //   try {
  //     String url = await firebaseStorageService.uploadFile(platformFile);
  //     var x = await FirebaseFunctions.instance
  //         .httpsCallable('pdf_to_text')
  //         .call({'url': url});
  //     return x.data.toString();
  //   } catch (e) {
  //     log("Error in pdfToText: $e");
  //     rethrow; // Rethrow the exception after logging
  //   }
  // }

  /// Converts a PDF to Markdown using the async pdfToMdJobs pipeline.
  ///
  /// Returns a Firebase Storage download URL for the generated Markdown file.
  Future<String> pdfToMarkdownUrl(
    PlatformFile platformFile, {
    Duration timeout = const Duration(minutes: 5),
    void Function(String jobId)? onJobId,
    void Function(String status)? onStatusChanged,
    String? runId,
  }) async {
    if (platformFile.name.isEmpty) {
      throw Exception('Missing PDF filename');
    }

    final createCallable = FirebaseFunctions.instance
        .httpsCallable('create_pdf_to_md_job');
    final startCallable = FirebaseFunctions.instance
        .httpsCallable('start_pdf_to_md_job');

    String jobId = '';
    String uploadPath = '';
    String outputPath = '';

    try {
      onStatusChanged?.call('creating');
      final createResp = await createCallable.call({
        'originalFilename': platformFile.name,
        if (runId != null && runId.isNotEmpty) 'runId': runId,
      });

      final created = Map<String, dynamic>.from(createResp.data ?? {});
      jobId = (created['jobId'] ?? '').toString();
      uploadPath = (created['uploadPath'] ?? '').toString();

      if (jobId.isEmpty || uploadPath.isEmpty) {
        throw Exception('PDF→MD job creation failed (missing jobId/uploadPath)');
      }

      onJobId?.call(jobId);
      onStatusChanged?.call('uploading');

      // Upload the PDF to the job-specific path.
      await firebaseStorageService.uploadFileToPath(
        platformFile,
        uploadPath,
        contentType: 'application/pdf',
      );

      // Mark job as queued to start processing.
      onStatusChanged?.call('queued');
      await startCallable.call({'jobId': jobId});

      // Wait for completion by listening to the job document.
      final docStream = FirebaseFirestore.instance
          .collection(_pdfToMdJobsCollection)
          .doc(jobId)
          .snapshots();

      final completer = Completer<DocumentSnapshot<Map<String, dynamic>>>();
      StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
      sub = docStream.listen(
        (snap) {
          final data = snap.data() ?? {};
          final status = (data['status'] ?? '').toString();
          if (status.isNotEmpty) {
            onStatusChanged?.call(status);
          }
          if (!completer.isCompleted && (status == 'done' || status == 'failed')) {
            completer.complete(snap);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
      );

      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await completer.future.timeout(timeout);
      } finally {
        await sub.cancel();
      }

      final data = snap.data() ?? {};
      final status = (data['status'] ?? '').toString();

      if (status == 'failed') {
        final err = (data['error'] ?? 'Unknown error').toString();
        throw Exception('PDF→MD job failed: $err');
      }

      outputPath = (data['outputPath'] ?? '').toString();
      if (outputPath.isEmpty) {
        throw Exception('PDF→MD job completed but outputPath is missing');
      }

      // Return a download URL for the generated markdown.
      final outputRef = FirebaseStorage.instance.ref(outputPath);
      return await outputRef.getDownloadURL();
    } on TimeoutException catch (e) {
      throw Exception('Timed out waiting for PDF→MD conversion: $e');
    } catch (e) {
      log('Error in pdfToMarkdownUrl: $e');
      rethrow;
    }
  }

  /// Back-compat API: converts PDF to Markdown and returns the Markdown text.
  ///
  /// This downloads the generated markdown file from Storage. Prefer
  /// [pdfToMarkdownUrl] to avoid large in-memory payloads.
  Future<String> pdfToMd(PlatformFile platformFile) async {
    final mdUrl = await pdfToMarkdownUrl(platformFile);
    final ref = firebaseStorageService.getFileReference(mdUrl);
    if (ref == null) {
      throw Exception('Could not resolve markdown Storage reference');
    }

    // Allow fairly large markdown payloads; increase if needed.
    final bytes = await ref.getData(20 * 1024 * 1024);
    if (bytes == null) {
      throw Exception('Failed to download generated markdown');
    }
    return String.fromCharCodes(bytes);
  }
}
