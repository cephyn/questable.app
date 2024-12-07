import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

class FirebaseStorageService {
  final storage = FirebaseStorage.instance;

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
    Reference ref = storage.ref().child('uploads/$fileName');
    UploadTask uploadTask = ref.putData(fileBytes, SettableMetadata(contentType: mimeType));
    await uploadTask.whenComplete(() => null);
    return await ref.getDownloadURL();
  }

  //get a file
  Reference getFileReference(String url) {
    return storage.refFromURL(url);
  }

  String getStorageUrl(Reference fileReference){
    final bucket = fileReference.bucket;
    final fullPath = fileReference.fullPath;
    return 'gs://$bucket/$fullPath';
  }

  //TODO: Delete File
  

}
