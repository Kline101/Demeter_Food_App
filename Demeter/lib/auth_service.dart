import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

class AuthService {
  static final AuthService instance = AuthService._(); // Singleton
  AuthService._(); // Private constructor

  final _auth = FirebaseAuth.instance; // Real Firebase
  FakeFirebaseFirestore? _firestore;  // For mocking

  // Use real Firebase or the fake one for testing
  FirebaseAuth getFirebaseAuthInstance() => _firestore != null ? _auth : _auth;

  // This function will help during testing setup
  void useFakeAuthentication(FakeFirebaseFirestore firestore) {
    _firestore = firestore;
  }

  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password}) async {
    try {
      await getFirebaseAuthInstance().createUserWithEmailAndPassword(
          email: email,
          password: password
      );
    } on FirebaseAuthException {
      // Rethrow error for handling or handle specific auth errors here
      rethrow;
    }
  }
}
