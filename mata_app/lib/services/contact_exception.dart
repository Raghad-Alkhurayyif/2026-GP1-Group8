enum ContactErrorType {
  emptyName,
  emptyPhone,
  invalidPhone,
  duplicatePhone,
  notFound,
  notSignedIn,
  network,
  unknown,
}

class ContactException implements Exception {
  const ContactException(this.type);

  final ContactErrorType type;

  String get message {
    switch (type) {
      case ContactErrorType.emptyName:
        return 'Please enter the contact name.';
      case ContactErrorType.emptyPhone:
        return 'Please enter the phone number.';
      case ContactErrorType.invalidPhone:
        return 'Please enter a valid Saudi mobile number.';
      case ContactErrorType.duplicatePhone:
        return 'This phone number is already saved.';
      case ContactErrorType.notFound:
        return 'The emergency contact could not be found.';
      case ContactErrorType.notSignedIn:
        return 'No signed-in user was found.';
      case ContactErrorType.network:
        return 'Please check your internet connection and try again.';
      case ContactErrorType.unknown:
        return 'The request could not be completed. Please try again.';
    }
  }

  @override
  String toString() => message;
}