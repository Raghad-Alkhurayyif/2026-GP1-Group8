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

  Future<void> updatePersonalInformation({
    required String name,
    required DateTime dateOfBirth,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    await _firestore.collection('users').doc(user.uid).update({
      'name': name.trim(),
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'user-not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'user-not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);

    final userDocument = _firestore.collection('users').doc(user.uid);

    final userSnapshot = await userDocument.get();
    final savedData = userSnapshot.data();

    await _deleteSymptomSubmissions(user.uid);
    await userDocument.delete();

    try {
      await user.delete();
      await _auth.signOut();
    } catch (error) {
      if (savedData != null) {
        await userDocument.set(savedData);
      }

      rethrow;
    }
  }

  Future<void> _deleteSymptomSubmissions(String userId) async {
    final collection = _firestore
        .collection('users')
        .doc(userId)
        .collection('symptomSubmissions');

    while (true) {
      final snapshot = await collection.limit(400).get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _firestore.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      await batch.commit();

      if (snapshot.docs.length < 400) {
        break;
      }
    }
  }
}
