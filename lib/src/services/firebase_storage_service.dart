import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

import '../util/utils.dart';

class FirebaseStorageService {
  final storage = FirebaseStorage.instance;

  // Map to keep track of download URLs to their corresponding storage paths
  final Map<String, String> _urlToPathMap = {};

  Future<String> uploadFile(PlatformFile file) async {
    Uint8List fileBytes;
    String? fileName;

    if (kIsWeb) {
      fileBytes = file.bytes!;
    } else {
      fileBytes = File(file.path!).readAsBytesSync();
    }
    fileName = file.name;
    var mimeType = lookupMimeType(file.name);

    FirebaseStorage storage = FirebaseStorage.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final safePrefix = DateTime.now().millisecondsSinceEpoch;
    final ownerFolder = uid ?? 'anonymous';
    String storagePath = 'uploads/$ownerFolder/${safePrefix}_$fileName';
    Reference ref = storage.ref().child(storagePath);
    UploadTask uploadTask =
        ref.putData(fileBytes, SettableMetadata(contentType: mimeType));
    await uploadTask.whenComplete(() => null);
    String downloadUrl = await ref.getDownloadURL();

    // Store mapping of download URL to storage path
    _urlToPathMap[downloadUrl] = storagePath;

    return downloadUrl;
  }

  /// Uploads a file to a specific Storage path (e.g., a job input path).
  ///
  /// Returns the download URL for the uploaded object.
  Future<String> uploadFileToPath(
    PlatformFile file,
    String storagePath, {
    String? contentType,
  }) async {
    Uint8List fileBytes;

    if (kIsWeb) {
      fileBytes = file.bytes!;
    } else {
      fileBytes = File(file.path!).readAsBytesSync();
    }

    final inferred = contentType ?? lookupMimeType(file.name);
    final Reference ref = storage.ref().child(storagePath);
    final UploadTask uploadTask = ref.putData(
      fileBytes,
      SettableMetadata(contentType: inferred),
    );
    await uploadTask.whenComplete(() => null);
    final downloadUrl = await ref.getDownloadURL();

    _urlToPathMap[downloadUrl] = storagePath;
    return downloadUrl;
  }

  Future<String> uploadTextFile(String text) async {
    Uint8List fileBytes;
    String? fileName;

    fileBytes = Uint8List.fromList(utf8.encode(text));
    String randomFilename = Utils.generateRandomString(16);
    fileName = 'QC$randomFilename.txt';
    var mimeType = "text/plain";

    FirebaseStorage storage = FirebaseStorage.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ownerFolder = uid ?? 'anonymous';
    String storagePath = 'uploads/$ownerFolder/$fileName';
    Reference ref = storage.ref().child(storagePath);
    UploadTask uploadTask =
        ref.putData(fileBytes, SettableMetadata(contentType: mimeType));
    await uploadTask.whenComplete(() => null);
    String downloadUrl = await ref.getDownloadURL();

    // Store mapping of download URL to storage path
    _urlToPathMap[downloadUrl] = storagePath;

    return downloadUrl;
  }

  //get a file
  Reference? getFileReference(String url) {
    try {
      // First try to get the file reference from our internal mapping
      if (_urlToPathMap.containsKey(url)) {
        return storage.ref(_urlToPathMap[url]);
      }

      // Fall back to the refFromURL method, which may not work with download URLs
      return storage.refFromURL(url);
    } catch (e) {
      debugPrint('Error getting file reference: $e');
      return null;
    }
  }

  /// Get a properly authenticated URL for a file reference
  /// This method generates an authenticated URL that can be used with Vertex AI
  Future<String> getStorageUrl(Reference fileReference) async {
    try {
      // First try to get a download URL with authentication token
      String downloadUrl = await fileReference.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error getting download URL: $e, falling back to gs:// URL');
      // Fall back to gs:// URL format
      final bucket = fileReference.bucket;
      final fullPath = fileReference.fullPath;
      return 'gs://$bucket/$fullPath';
    }
  }

  // Delete a file from Firebase Storage
  Future<bool> deleteFile(String url) async {
    try {
      Reference? fileReference = getFileReference(url);
      if (fileReference == null) {
        // Try a different approach - extract path from URL
        try {
          // Handle both download URLs and gs:// URLs
          Uri uri = Uri.parse(url);
          String path = '';

          if (url.startsWith('https://firebasestorage.googleapis.com')) {
            // Extract path from the Firebase storage download URL
            // The path is typically in the 'o' query parameter
            path = uri.queryParameters['o'] ?? '';
            if (path.isEmpty) {
              // Try the path part as well
              path = uri.path;
              // Remove the /v0/b/[bucket]/o/ prefix if present
              RegExp pathRegex = RegExp(r'/v0/b/[^/]+/o/(.+)');
              var match = pathRegex.firstMatch(path);
              if (match != null && match.groupCount >= 1) {
                path = match.group(1)!;
                // URL-decode the path
                path = Uri.decodeComponent(path);
              }
            }
          } else if (url.startsWith('gs://')) {
            // Handle gs:// URLs
            path = url.replaceFirst(RegExp(r'gs://[^/]+/'), '');
          }

          if (path.isNotEmpty) {
            debugPrint('Attempting to delete file with extracted path: $path');
            fileReference = storage.ref(path);
          } else {
            debugPrint('Could not extract path from URL: $url');
            return false;
          }
        } catch (pathError) {
          debugPrint('Error extracting path from URL: $pathError');
          return false;
        }
      }

      try {
        await fileReference.delete();
      } on FirebaseException catch (e) {
        // Treat missing objects as a successful cleanup.
        // This commonly happens when an async worker already deleted the upload.
        if (e.code != 'object-not-found') {
          rethrow;
        }
      }

      // Remove the mapping if deletion was successful
      _urlToPathMap.remove(url);

      return true; // Return true on successful deletion
    } catch (e) {
      // Log error but don't rethrow so application flow isn't interrupted
      debugPrint('Error deleting file from storage: $e');
      return false; // Return false on failed deletion
    }
  }
}
