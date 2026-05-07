import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverMessage {
  final String id;
  final String caregiverUid;
  final String caregiverName;
  final String seniorUid;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  CaregiverMessage({
    required this.id,
    required this.caregiverUid,
    required this.caregiverName,
    required this.seniorUid,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory CaregiverMessage.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['createdAt'];
    return CaregiverMessage(
      id: id,
      caregiverUid: (map['caregiverUid'] ?? '').toString(),
      caregiverName: (map['caregiverName'] ?? 'Your caregiver').toString(),
      seniorUid: (map['seniorUid'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      isRead: map['isRead'] == true,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
