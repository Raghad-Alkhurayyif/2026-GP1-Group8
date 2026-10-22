import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssessmentService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createSymptomSubmission({required String description}) async {
    final user = _auth.currentUser;
    final cleanedDescription = description.trim();

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    if (cleanedDescription.isEmpty) {
      throw ArgumentError('The symptom description cannot be empty.');
    }

    final submission = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('symptomSubmissions')
        .doc();

    await submission.set({
      'userId': user.uid,
      'description': cleanedDescription,
      'recognizedSymptoms': <Map<String, dynamic>>[],
      'subject': null,
      'subjectAge': null,
      'status': 'processing',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return submission.id;
  }

  Future<void> completeSymptomSubmission({
    required String submissionId,
    required List<dynamic> symptoms,
    required List<dynamic> negatedSymptoms,
    required bool isForCurrentUser,
    required int subjectAge,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    final recognizedSymptoms = [
      ..._prepareSymptoms(symptoms, isAsserted: true),
      ..._prepareSymptoms(negatedSymptoms, isAsserted: false),
    ];

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('symptomSubmissions')
        .doc(submissionId)
        .update({
          'recognizedSymptoms': recognizedSymptoms,
          'subject': isForCurrentUser ? 'self' : 'other',
          'subjectAge': subjectAge,
          'status': 'confirmed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> failSymptomSubmission({required String submissionId}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('symptomSubmissions')
        .doc(submissionId)
        .update({
          'status': 'failed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  List<Map<String, dynamic>> _prepareSymptoms(
    List<dynamic> symptoms, {
    required bool isAsserted,
  }) {
    return symptoms
        .whereType<Map>()
        .map(
          (symptom) => {
            'column': symptom['column']?.toString(),
            'isAsserted': isAsserted,
            'matchedText': symptom['matched_text']?.toString(),
            'layer': symptom['layer']?.toString(),
          },
        )
        .where(
          (symptom) =>
              symptom['column'] != null &&
              symptom['column'].toString().trim().isNotEmpty,
        )
        .toList();
  }

  Future<int> getCurrentUserAge() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();

    final dateOfBirth = snapshot.data()?['dateOfBirth'];

    if (dateOfBirth is! Timestamp) {
      throw StateError('The user date of birth was not found.');
    }

    final birthDate = dateOfBirth.toDate();
    final today = DateTime.now();

    var age = today.year - birthDate.year;

    final birthdayHasNotOccurred =
        today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day);

    if (birthdayHasNotOccurred) {
      age--;
    }

    return age;
  }
}
