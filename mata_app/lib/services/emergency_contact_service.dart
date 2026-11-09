import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/emergency_contact.dart';
import 'contact_exception.dart';

class EmergencyContactService {
  EmergencyContactService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<List<EmergencyContact>> getContacts() {
    return _execute(() async {
      final contacts = _contactsCollection();
      final snapshot = await contacts.get();

      final result = snapshot.docs
          .map(
            (document) => EmergencyContact.fromMap(
              document.id,
              document.data(),
            ),
          )
          .toList();

      result.sort((first, second) {
        if (first.isDefault != second.isDefault) {
          return first.isDefault ? -1 : 1;
        }

        return first.name.toLowerCase().compareTo(
              second.name.toLowerCase(),
            );
      });

      return result;
    });
  }

  /// Saves a new contact and returns its id, so the screen can make it the
  /// default when the user asks for that.
  Future<String> addContact(
    String name,
    String phone,
  ) {
    return _execute(() async {
      final cleanedName = _validateName(name);
      final normalizedPhone = _normalizePhone(phone);
      final contacts = _contactsCollection();

      await _ensurePhoneIsUnique(
        contacts,
        normalizedPhone,
      );

      final document = await contacts.add({
        'name': cleanedName,
        'phoneNumber': normalizedPhone,
        'isDefault': false,
      });

      return document.id;
    });
  }

  Future<void> updateContact(
    EmergencyContact contact,
  ) {
    return _execute(() async {
      final cleanedName = _validateName(contact.name);
      final normalizedPhone =
          _normalizePhone(contact.phoneNumber);
      final contacts = _contactsCollection();
      final document = contacts.doc(contact.id);

      final snapshot = await document.get();

      if (!snapshot.exists) {
        throw const ContactException(
          ContactErrorType.notFound,
        );
      }

      await _ensurePhoneIsUnique(
        contacts,
        normalizedPhone,
        excludedContactId: contact.id,
      );

      await document.update({
        'name': cleanedName,
        'phoneNumber': normalizedPhone,
      });
    });
  }

  Future<void> deleteContact(String id) {
    return _execute(() async {
      final user = _requireUser();
      final contacts = _contactsCollection();
      final document = contacts.doc(id);
      final snapshot = await document.get();

      if (!snapshot.exists) {
        throw const ContactException(
          ContactErrorType.notFound,
        );
      }

      final isDefault =
          snapshot.data()?['isDefault'] as bool? ?? false;

      if (!isDefault) {
        await document.delete();
        return;
      }

      final batch = _firestore.batch();

      batch.delete(document);
      batch.update(
        _firestore.collection('users').doc(user.uid),
        {'defaultEmergencyContactId': null},
      );

      await batch.commit();
    });
  }

  Future<void> setDefault(String id) {
    return _execute(() async {
      final user = _requireUser();
      final contacts = _contactsCollection();
      final selectedContact = contacts.doc(id);
      final selectedSnapshot =
          await selectedContact.get();

      if (!selectedSnapshot.exists) {
        throw const ContactException(
          ContactErrorType.notFound,
        );
      }

      final currentDefaults = await contacts
          .where('isDefault', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (final document in currentDefaults.docs) {
        if (document.id != id) {
          batch.update(
            document.reference,
            {'isDefault': false},
          );
        }
      }

      batch.update(
        selectedContact,
        {'isDefault': true},
      );

      batch.update(
        _firestore.collection('users').doc(user.uid),
        {'defaultEmergencyContactId': id},
      );

      await batch.commit();
    });
  }

  Future<EmergencyContact?> getDefaultContact() {
    return _execute(() async {
      final snapshot = await _contactsCollection()
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final document = snapshot.docs.first;

      return EmergencyContact.fromMap(
        document.id,
        document.data(),
      );
    });
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw const ContactException(
        ContactErrorType.notSignedIn,
      );
    }

    return user;
  }

  CollectionReference<Map<String, dynamic>>
      _contactsCollection() {
    final user = _requireUser();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('emergencyContacts');
  }

  String _validateName(String name) {
    final cleanedName = name.trim();

    if (cleanedName.isEmpty) {
      throw const ContactException(
        ContactErrorType.emptyName,
      );
    }

    return cleanedName;
  }

  String _normalizePhone(String phone) {
    final cleanedPhone = phone.replaceAll(
      RegExp(r'[\s()-]'),
      '',
    );

    if (RegExp(r'^05\d{8}$').hasMatch(cleanedPhone)) {
      return '+966${cleanedPhone.substring(1)}';
    }

    if (RegExp(r'^\+9665\d{8}$')
        .hasMatch(cleanedPhone)) {
      return cleanedPhone;
    }

    if (cleanedPhone.isEmpty) {
      throw const ContactException(
        ContactErrorType.emptyPhone,
      );
    }

    throw const ContactException(
      ContactErrorType.invalidPhone,
    );
  }

  Future<void> _ensurePhoneIsUnique(
    CollectionReference<Map<String, dynamic>> contacts,
    String phone, {
    String? excludedContactId,
  }) async {
    final snapshot = await contacts
        .where('phoneNumber', isEqualTo: phone)
        .get();

    final duplicateExists = snapshot.docs.any(
      (document) => document.id != excludedContactId,
    );

    if (duplicateExists) {
      throw const ContactException(
        ContactErrorType.duplicatePhone,
      );
    }
  }

  Future<T> _execute<T>(
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on ContactException {
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'network-request-failed') {
        throw const ContactException(
          ContactErrorType.network,
        );
      }

      if (error.code == 'not-found') {
        throw const ContactException(
          ContactErrorType.notFound,
        );
      }

      throw const ContactException(
        ContactErrorType.unknown,
      );
    }
  }
}