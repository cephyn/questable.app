
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../util/utils.dart';
import 'local_user.dart';

class LocalUserEdit extends StatefulWidget {
  final String userId;
  const LocalUserEdit({super.key, required this.userId});

  @override
  State<LocalUserEdit> createState() {
    return _LocalUserEditState();
  }
}

class _LocalUserEditState extends State<LocalUserEdit> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService firestoreService = FirestoreService();
  LocalUser? _localUser;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle("Edit User");
    return StreamBuilder<DocumentSnapshot>(
      stream: firestoreService.getUserCardStream(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')));
        } else if (snapshot.hasData) {
          Map<String, dynamic> data =
              snapshot.data!.data() as Map<String, dynamic>;
          _localUser = LocalUser.fromMap(data);
          _localUser?.uid = widget.userId;
          return Scaffold(
            appBar: AppBar(title: Text('Edit User')),
            body: getUserForm(context),
          );
        } else {
          return Scaffold(body: Center(child: Text('No data found')));
        }
      },
    );
  }

  Form getUserForm(BuildContext context) {
    final List<String> availableRoles = [
      'admin',
      'user',
      'signup'
    ]; // Define available roles

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return ListView(
              children: <Widget>[
                _buildInfoRow('Email', _localUser?.email),
                _buildInfoRow('UID', _localUser?.uid),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Roles',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                // Create checkboxes for each role
                ...availableRoles.map((role) {
                  return CheckboxListTile(
                    title: Text(role),
                    value: _localUser?.roles.contains(role) ?? false,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _localUser?.roles.add(role);
                        } else {
                          _localUser?.roles.remove(role);
                        }
                      });
                    },
                  );
                }),
                SizedBox(height: 16), // Add space before the submit button
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState?.save();
                        await firestoreService.updateUser(_localUser!);
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      textStyle: TextStyle(fontSize: 16),
                    ),
                    child: const Text('Submit'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child:
                Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 3,
            child:
                Text(value ?? 'N/A', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}