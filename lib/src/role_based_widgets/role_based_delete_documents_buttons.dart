import 'package:flutter/material.dart';
import 'package:quest_cards/src/services/firestore_service.dart';

class RoleBasedDeleteDocumentsButtons {
  final FirestoreService firestoreService = FirestoreService();

  FutureBuilder<List<String>?> deleteQuestCardButton(
      String userId, String docId) {
    return FutureBuilder<List<String>?>(
      future: firestoreService.getUserRoles(userId),
      builder: (BuildContext context, AsyncSnapshot<List<String>?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return SelectableText('Error: ${snapshot.error}');
        } else if (snapshot.hasData) {
          List<String>? roles = snapshot.data;
          if (roles != null && roles.contains('admin')) {
            return IconButton(
              icon: Icon(Icons.delete),
              onPressed: () async {
                // Show confirmation dialog before deleting
                final bool confirmDelete =
                    await _showDeleteConfirmationDialog(context);
                if (confirmDelete) {
                  await firestoreService.deleteQuestCard(docId);
                  // Show a snackbar confirming deletion
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quest deleted successfully'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              tooltip: 'Delete Quest',
            );
          } else {
            return Container(); // Or any other widget for non-admin users
          }
        } else {
          return Text('No roles found');
        }
      },
    );
  }

  // Helper method to show the delete confirmation dialog
  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false, // User must tap a button to dismiss dialog
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text(
                'Are you sure you want to delete this quest? This action cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // User canceled deletion
                  },
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // User confirmed deletion
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red, // Make the delete button red
                  ),
                  child: const Text('DELETE'),
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if dialog is dismissed
  }

  FutureBuilder<List<String>?> deleteUserButton(String userId, String docId) {
    return FutureBuilder<List<String>?>(
      future: firestoreService.getUserRoles(userId),
      builder: (BuildContext context, AsyncSnapshot<List<String>?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData) {
          List<String>? roles = snapshot.data;
          if (roles != null && roles.contains('admin')) {
            return IconButton(
              icon: Icon(Icons.delete),
              onPressed: () async {
                await firestoreService.deleteUser(docId);
              },
            );
          } else {
            return Container(); // Or any other widget for non-admin users
          }
        } else {
          return Text('No roles found');
        }
      },
    );
  }
}
