import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../role_based_widgets/role_based_delete_documents_buttons.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';
import '../util/utils.dart';
import 'local_user.dart';
import 'local_user_edit.dart';

class LocalUserList extends StatelessWidget {
  LocalUserList({super.key});
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();
  final RoleBasedDeleteDocumentsButtons rbDeleteDocumentsButtons =
      RoleBasedDeleteDocumentsButtons();

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle("List Users");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
      ),
      body: Center(
        child: StreamBuilder<QuerySnapshot>(
          stream: firestoreService.getUsersStream(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              List<QueryDocumentSnapshot> usersList = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: usersList.length,
                itemBuilder: (context, index) {
                  DocumentSnapshot document = usersList[index];
                  Map<String, dynamic> data =
                      document.data() as Map<String, dynamic>;
                  LocalUser user = LocalUser.fromMap(data);
                  user.uid = document.id;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(
                        user.email,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(user.roles.join(", ")),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      LocalUserEdit(userId: user.uid),
                                ),
                              );
                            },
                          ),
                          Builder(builder: (context) {
                            final currentUser = auth.getCurrentUser();
                            if (currentUser == null) return Container();
                            return rbDeleteDocumentsButtons
                                .deleteUserButton(currentUser.uid, user.uid);
                          }),
                        ],
                      ),
                    ),
                  );
                },
              );
            } else {
              return const Text("No Users");
            }
          },
        ),
      ),
    );
  }
}
