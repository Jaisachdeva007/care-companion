class Medication {
  final String id;
  final String name;
  final String dosage;
  final List<String> scheduleTimes;
  final List<String> repeatDays;
  final String notes;
  final DateTime? refillDate;
  final bool isActive;
  final List<MedicationLog> logs;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.scheduleTimes,
    required this.repeatDays,
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
      repeatDays: List<String>.from(map['repeatDays'] ?? []),
      notes: map['notes'] ?? '',
      refillDate: map['refillDate'] != null
          ? DateTime.tryParse(map['refillDate'])
          : null,
      isActive: map['isActive'] ?? true,
      logs: (map['logs'] as List<dynamic>? ?? [])
          .map((log) => MedicationLog.fromMap(Map<String, dynamic>.from(log)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'scheduleTimes': scheduleTimes,
      'repeatDays': repeatDays,
      'notes': notes,
      'refillDate': refillDate?.toIso8601String(),
      'isActive': isActive,
      'logs': logs.map((log) => log.toMap()).toList(),
    };
  }

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    List<String>? scheduleTimes,
    List<String>? repeatDays,
    String? notes,
    DateTime? refillDate,
    bool? isActive,
    List<MedicationLog>? logs,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      repeatDays: repeatDays ?? this.repeatDays,
      notes: notes ?? this.notes,
      refillDate: refillDate ?? this.refillDate,
      isActive: isActive ?? this.isActive,
      logs: logs ?? this.logs,
    );
  }
}

class MedicationLog {
  final DateTime scheduledTime;
  final DateTime? actionTime;
  final String status;

  MedicationLog({
    required this.scheduledTime,
    this.actionTime,
    required this.status,
  });

  factory MedicationLog.fromMap(Map<String, dynamic> map) {
    return MedicationLog(
      scheduledTime: DateTime.parse(map['scheduledTime']),
      actionTime: map['actionTime'] != null
          ? DateTime.tryParse(map['actionTime'])
          : null,
      status: map['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduledTime': scheduledTime.toIso8601String(),
      'actionTime': actionTime?.toIso8601String(),
      'status': status,
    };
  }
}