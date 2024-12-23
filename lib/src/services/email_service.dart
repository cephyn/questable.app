import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

class EmailService {
  final CollectionReference emails =
      FirebaseFirestore.instance.collection('emails');

  Future<void> sendSignupEmailToAdmin(String userEmail) async {
    String docId = "";
    await emails.add({
      'to': [
        {'email': 'admin@questable.app', 'name': 'Questable Admin'}
      ],
      'from': {
        'email': 'noreply@questable.app',
        'name': 'noreply@questable.app'
      },
      'subject': 'New Questable Signup!',
      'html': 'New signup for Questable.app from $userEmail',
    }).then((DocumentReference ref) {
      docId = ref.id;
    });
    //print(docId);
    log(docId);
  }

  Future<void> sendNonAdventureEmailToAdmin(String adventureJson) async {
    await emails.add({
      'to': [
        {'email': 'admin@questable.app', 'name': 'Questable Admin'}
      ],
      'from': {
        'email': 'noreply@questable.app',
        'name': 'noreply@questable.app'
      },
      'subject': 'Questable: Non-Adventure Uploaded',
      'html':
          'AI has detected a non-adventure file: <code>$adventureJson</code>',
    }).then((DocumentReference ref) {});
  }

  Future<void> sendActivationEmail(String userEmail) async {
    await emails.add({
      'to': [
        {'email': userEmail}
      ],
      'from': {'email': 'admin@questable.app', 'name': 'admin@questable.app'},
      'subject': 'Questable User Account Activated',
      'html':
          'Hello! Thank you for signing up for beta testing of <a href=https://questable.app>Questable</a>. Your user account has been activated and you may log in! Please let us know what features you would like to see in the app. Test out adventure analysis and let us know how it did! <br> <br> - The Questable Team',
    }).then((DocumentReference ref) {});
  }
}
