class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String role;
  final String language;
  final String phone;
  final String address;
  final List<Map<String, dynamic>> emergencyContacts;
  final bool profileCompleted;
  final String? linkedCaregiverUid;
  final String? linkedSeniorUid;

  AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.language,
    required this.phone,
    required this.address,
    required this.emergencyContacts,
    required this.profileCompleted,
    this.linkedCaregiverUid,
    this.linkedSeniorUid,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: map['role'] ?? 'senior',
      language: map['language'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      emergencyContacts:
          List<Map<String, dynamic>>.from(map['emergencyContacts'] ?? []),
      profileCompleted: map['profileCompleted'] ?? false,
      linkedCaregiverUid: map['linkedCaregiverUid'],
      linkedSeniorUid: map['linkedSeniorUid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role,
      'language': language,
      'phone': phone,
      'address': address,
      'emergencyContacts': emergencyContacts,
      'profileCompleted': profileCompleted,
      'linkedCaregiverUid': linkedCaregiverUid,
      'linkedSeniorUid': linkedSeniorUid,
    };
  }
}