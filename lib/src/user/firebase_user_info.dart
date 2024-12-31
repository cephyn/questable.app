// Define a model class for User Info
class FirebaseUserInfo {
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String? photoURL;
  final String providerId;
  final String uid;

  FirebaseUserInfo({
    required this.displayName,
    required this.email,
    this.phoneNumber,
    this.photoURL,
    required this.providerId,
    required this.uid,
  });
}
