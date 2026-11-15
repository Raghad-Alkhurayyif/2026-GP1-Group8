import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

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
    String phone, {
    IsoCode? country,
  }) {
    return _execute(() async {
      final cleanedName = _validateName(name);
      final normalizedPhone = _normalizePhone(phone, country);
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
    EmergencyContact contact, {
    IsoCode? country,
  }) {
    return _execute(() async {
      final cleanedName = _validateName(contact.name);
      final normalizedPhone =
          _normalizePhone(contact.phoneNumber, country);
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
      final contacts = _contactsCollection();
      final userDocument = contacts.parent!;
      final document = contacts.doc(id);

      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocument);
        final snapshot = await transaction.get(document);

        if (!snapshot.exists) {
          throw const ContactException(ContactErrorType.notFound);
        }

        transaction.delete(document);
        final defaultId = userSnapshot.data()?['defaultEmergencyContactId'];
        if (defaultId == id) {
          transaction.update(userDocument, {'defaultEmergencyContactId': null});
        }
      });
    });
  }

  Future<void> setDefault(String id) {
    return _execute(() async {
      final contacts = _contactsCollection();
      final userDocument = contacts.parent!;
      final selectedContact = contacts.doc(id);
      final flaggedDefaults = await contacts
          .where('isDefault', isEqualTo: true)
          .get(const GetOptions(source: Source.server));

      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocument);
        final selectedSnapshot = await transaction.get(selectedContact);

        if (!selectedSnapshot.exists) {
          throw const ContactException(ContactErrorType.notFound);
        }

        final previousId =
            userSnapshot.data()?['defaultEmergencyContactId'] as String?;
        final previousIds = {
          for (final document in flaggedDefaults.docs) document.id,
          if (previousId != null) previousId,
        }..remove(id);

        final previousSnapshots = await Future.wait(
          previousIds.map(
            (previousId) => transaction.get(contacts.doc(previousId)),
          ),
        );
        for (final snapshot in previousSnapshots) {
          if (snapshot.data()?['isDefault'] == true) {
            transaction.update(snapshot.reference, {'isDefault': false});
          }
        }

        transaction.update(selectedContact, {'isDefault': true});
        transaction.update(userDocument, {'defaultEmergencyContactId': id});
      });
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

  String _normalizePhone(String phone, IsoCode? country) {
    final cleanedPhone = phone.replaceAll(RegExp(r'[\s().-]'), '');
    if (cleanedPhone.isEmpty) {
      throw const ContactException(ContactErrorType.emptyPhone);
    }

    if (!RegExp(r'^\+?[0-9٠-٩۰-۹]+$').hasMatch(cleanedPhone) ||
        (country == null && !cleanedPhone.startsWith('+'))) {
      throw const ContactException(ContactErrorType.invalidPhone);
    }

    try {
      final number = PhoneNumber.parse(cleanedPhone, callerCountry: country);
      if ((country == null || number.isoCode == country) &&
          number.isValid(type: PhoneNumberType.mobile)) {
        return number.international;
      }
    } on PhoneNumberException {
      throw const ContactException(ContactErrorType.invalidPhone);
    }

    throw const ContactException(ContactErrorType.invalidPhone);
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