import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationLog {
  final DateTime scheduledTime;
  final DateTime? actionTime;
  final String status; // pending, taken, missed, skipped

  MedicationLog({
    required this.scheduledTime,
    this.actionTime,
    required this.status,
  });

  factory MedicationLog.fromMap(Map<String, dynamic> map) {
    return MedicationLog(
      scheduledTime: (map['scheduledTime'] as Timestamp).toDate(),
      actionTime: map['actionTime'] != null
          ? (map['actionTime'] as Timestamp).toDate()
          : null,
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'actionTime': actionTime != null ? Timestamp.fromDate(actionTime!) : null,
      'status': status,
    };
  }
}

class Medication {
  final String id;
  final String name;
  final String dosage;
  final List<String> scheduleTimes; // e.g. ["08:00", "20:00"]
  final String notes;
  final DateTime? refillDate;
  final bool isActive;
  final List<MedicationLog> logs;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.scheduleTimes,
    required this.notes,
    required this.refillDate,
    required this.isActive,
    required this.logs,
  });

  factory Medication.fromMap(String id, Map<String, dynamic> map) {
    return Medication(
      id: id,
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      scheduleTimes: List<String>.from(map['scheduleTimes'] ?? []),
      notes: map['notes'] ?? '',
      refillDate: map['refillDate'] != null
          ? (map['refillDate'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] ?? true,
      logs: (map['logs'] as List<dynamic>? ?? [])
          .map((e) => MedicationLog.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'scheduleTimes': scheduleTimes,
      'notes': notes,
      'refillDate': refillDate != null ? Timestamp.fromDate(refillDate!) : null,
      'isActive': isActive,
      'logs': logs.map((e) => e.toMap()).toList(),
    };
  }
}