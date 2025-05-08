import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';

import 'firebase_storage_service.dart';

class FirebaseFunctionsService {
  final FirebaseStorageService firebaseStorageService =
      FirebaseStorageService();

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

  Future<String> pdfToMd(PlatformFile platformFile) async {
    String? url;
    try {
      url = await firebaseStorageService.uploadFile(platformFile);
      var x = await FirebaseFunctions.instance
          .httpsCallable('pdf_to_md')
          .call({'url': url});
      return x.data.toString();
    } catch (e) {
      // Handle network errors or exceptions during the call
      log("Error in pdfToMd: $e");
      rethrow;
    } finally {
      // Optionally, you can add cleanup code here if needed
      // For example, deleting the uploaded file from Firebase Storage
      if (url != null) {
        await firebaseStorageService.deleteFile(url);
      }
    }
  }
}
