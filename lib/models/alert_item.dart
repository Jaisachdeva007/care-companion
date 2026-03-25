import 'package:cloud_firestore/cloud_firestore.dart';

class AlertItem {
  final String id;
  final String seniorUid;
  final String seniorName;
  final List<String> caregiverUids;
  final String type;
  final String message;
  final String status;
  final DateTime? createdAt;

  AlertItem({
    required this.id,
    required this.seniorUid,
    required this.seniorName,
    required this.caregiverUids,
    required this.type,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory AlertItem.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['createdAt'];

    return AlertItem(
      id: id,
      seniorUid: (map['seniorUid'] ?? '').toString(),
      seniorName: (map['seniorName'] ?? '').toString(),
      caregiverUids: List<String>.from(map['caregiverUids'] ?? []),
      type: (map['type'] ?? 'check_on_me').toString(),
      message: (map['message'] ?? 'Please check on me.').toString(),
      status: (map['status'] ?? 'active').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seniorUid': seniorUid,
      'seniorName': seniorName,
      'caregiverUids': caregiverUids,
      'type': type,
      'message': message,
      'status': status,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }
}