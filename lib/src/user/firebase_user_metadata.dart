// Define a model class for User Metadata
class FirebaseUserMetadata {
  final DateTime creationTime;
  final DateTime lastSignInTime;

  FirebaseUserMetadata(
      {required this.creationTime, required this.lastSignInTime});
}
