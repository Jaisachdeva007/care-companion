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

  final String? caregiverCode;
  final List<String> linkedCaregiverUids;
  final List<String> linkedSeniorUids;

  final String preferredName;
  final String age;
  final String bloodGroup;
  final String importantInfo;
  final List<String> healthConditions;
  final List<String> allergies;
  final List<String> medications;
  final String mobilityNeeds;
  final String inputPreference;
  final bool voiceAssistantEnabled;
  final bool largeTextEnabled;
  final bool questionnaireCompleted;
  final String photoBase64;

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
    this.caregiverCode,
    required this.linkedCaregiverUids,
    required this.linkedSeniorUids,
    required this.preferredName,
    required this.age,
    required this.bloodGroup,
    required this.importantInfo,
    required this.healthConditions,
    required this.allergies,
    required this.medications,
    required this.mobilityNeeds,
    required this.inputPreference,
    required this.voiceAssistantEnabled,
    required this.largeTextEnabled,
    required this.questionnaireCompleted,
    this.photoBase64 = '',
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final linkedCaregiverUids = List<String>.from(
      map['linkedCaregiverUids'] ??
          ((map['linkedCaregiverUid'] != null &&
                  map['linkedCaregiverUid'].toString().isNotEmpty)
              ? [map['linkedCaregiverUid'].toString()]
              : []),
    );

    final linkedSeniorUids = List<String>.from(
      map['linkedSeniorUids'] ??
          ((map['linkedSeniorUid'] != null &&
                  map['linkedSeniorUid'].toString().isNotEmpty)
              ? [map['linkedSeniorUid'].toString()]
              : []),
    );

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
      caregiverCode: map['caregiverCode'],
      linkedCaregiverUids: linkedCaregiverUids,
      linkedSeniorUids: linkedSeniorUids,
      preferredName: map['preferredName'] ?? '',
      age: map['age'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      importantInfo: map['importantInfo'] ?? '',
      healthConditions: List<String>.from(map['healthConditions'] ?? []),
      allergies: List<String>.from(map['allergies'] ?? []),
      medications: List<String>.from(map['medications'] ?? []),
      mobilityNeeds: map['mobilityNeeds'] ?? '',
      inputPreference: map['inputPreference'] ?? '',
      voiceAssistantEnabled: map['voiceAssistantEnabled'] ?? false,
      largeTextEnabled: map['largeTextEnabled'] ?? false,
      questionnaireCompleted: map['questionnaireCompleted'] ?? false,
      photoBase64: map['photoBase64'] ?? '',
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
      'caregiverCode': caregiverCode,
      'linkedCaregiverUids': linkedCaregiverUids,
      'linkedSeniorUids': linkedSeniorUids,
      'preferredName': preferredName,
      'age': age,
      'bloodGroup': bloodGroup,
      'importantInfo': importantInfo,
      'healthConditions': healthConditions,
      'allergies': allergies,
      'medications': medications,
      'mobilityNeeds': mobilityNeeds,
      'inputPreference': inputPreference,
      'voiceAssistantEnabled': voiceAssistantEnabled,
      'largeTextEnabled': largeTextEnabled,
      'questionnaireCompleted': questionnaireCompleted,
      'photoBase64': photoBase64,
    };
  }
}