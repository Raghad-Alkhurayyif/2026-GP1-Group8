class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final bool isDefault;

  factory EmergencyContact.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return EmergencyContact(
      id: id,
      name: data['name'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'isDefault': isDefault,
    };
  }

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    bool? isDefault,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}