import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> signUp({
    required String name,
    required DateTime dateOfBirth,
    required String email,
    required String password,
  }) async {
    User? createdUser;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw FirebaseAuthException(
          code: 'account-creation-failed',
          message: 'The account could not be created.',
        );
      }

      await _firestore.collection('users').doc(createdUser.uid).set({
        'name': name.trim(),
        'dateOfBirth': Timestamp.fromDate(dateOfBirth),
        'email': createdUser.email,
        'defaultEmergencyContactId': null,
      });
    } catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }

      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
