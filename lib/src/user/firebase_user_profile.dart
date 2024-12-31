import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';
import 'firebase_user_metadata.dart';

// Define a model class for Firebase User Profile
class FirebaseUserProfile {
  final String displayName;
  final String email;
  final bool isEmailVerified;
  final bool isAnonymous;
  final FirebaseUserMetadata metadata;
  final String? phoneNumber;
  final String? photoURL;
  final List<UserInfo> providerData;
  final String refreshToken;
  final String? tenantId;
  final String uid;

  FirebaseUserProfile({
    required this.displayName,
    required this.email,
    required this.isEmailVerified,
    required this.isAnonymous,
    required this.metadata,
    this.phoneNumber,
    this.photoURL,
    required this.providerData,
    required this.refreshToken,
    this.tenantId,
    required this.uid,
  });
}

// Define a Flutter widget to display the Firebase User Profile
class FirebaseUserProfileWidget extends StatelessWidget {
  final FirebaseUserProfile userProfile;
  final FirebaseAuthService auth;

  const FirebaseUserProfileWidget(
      {super.key, required this.userProfile, required this.auth});

  Future<void> _signOut(BuildContext context) async {
    await auth.signOut();
    Navigator.of(context).pop(); // Navigate back after signing out
  }

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      await auth.deleteCurrentUser();
      Navigator.of(context).pop(); // Navigate back after deleting account
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(userProfile.displayName),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: userProfile.photoURL != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(userProfile.photoURL!),
                        radius: 30,
                      )
                    : Icon(Icons.person, size: 50),
                title: Text(
                  userProfile.displayName,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  userProfile.email,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            ),
            SizedBox(height: 20),
            _buildInfoTile('Email Verified',
                userProfile.isEmailVerified ? 'Yes' : 'No', Icons.verified),
            _buildInfoTile('Anonymous', userProfile.isAnonymous ? 'Yes' : 'No',
                Icons.privacy_tip),
            _buildInfoTile(
                'Creation Time',
                userProfile.metadata.creationTime.toLocal().toString(),
                Icons.timer),
            _buildInfoTile(
                'Last Sign In',
                userProfile.metadata.lastSignInTime.toLocal().toString(),
                Icons.access_time),
            if (userProfile.phoneNumber != null)
              _buildInfoTile(
                  'Phone Number', userProfile.phoneNumber!, Icons.phone),
            _buildProviderData(userProfile.providerData),
            Spacer(),
            ElevatedButton(
              onPressed: () => _signOut(context),
              child: Text('Sign Out'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Red color for delete button
              ),
              onPressed: () => _deleteAccount(context),
              child: Text(
                'Delete Account',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderData(List<UserInfo> providerData) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Provider Data:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...providerData.map((info) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.account_circle, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${info.providerId}: ${info.email}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
