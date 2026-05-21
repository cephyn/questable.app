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
                  style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            SizedBox(height: 20),
            _buildInfoTile(context, 'Email Verified',
                userProfile.isEmailVerified ? 'Yes' : 'No', Icons.verified),
            _buildInfoTile(context, 'Anonymous', userProfile.isAnonymous ? 'Yes' : 'No',
                Icons.privacy_tip),
            _buildInfoTile(context, 'Creation Time',
              userProfile.metadata.creationTime.toLocal().toString(),
              Icons.timer),
            _buildInfoTile(context, 'Last Sign In',
              userProfile.metadata.lastSignInTime.toLocal().toString(),
              Icons.access_time),
            if (userProfile.phoneNumber != null)
              _buildInfoTile(context, 'Phone Number', userProfile.phoneNumber!, Icons.phone),
            _buildProviderData(context, userProfile.providerData),
            Spacer(),
            ElevatedButton(
              onPressed: () => _signOut(context),
              child: Text('Sign Out'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => _deleteAccount(context),
              child: Text(
                'Delete Account',
                style: TextStyle(color: Theme.of(context).colorScheme.onError),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
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

  Widget _buildProviderData(BuildContext context, List<UserInfo> providerData) {
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
                    Icon(Icons.account_circle, color: Theme.of(context).colorScheme.secondary),
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
