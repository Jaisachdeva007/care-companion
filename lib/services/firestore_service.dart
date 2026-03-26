import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_item.dart';
import '../models/app_user.dart';
import '../models/medication.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createBasicUser({
    required String uid,
    required String email,
    String fullName = '',
    String role = 'senior',
  }) async {
    final doc = _db.collection('users').doc(uid);

    final snapshot = await doc.get();
    if (snapshot.exists) return;

    await doc.set({
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role.toLowerCase(),
      'language': '',
      'phone': '',
      'address': '',
      'emergencyContacts': [],
      'profileCompleted': false,
      'questionnaireCompleted': role.toLowerCase() == 'caregiver',
      'preferredName': '',
      'age': '',
      'bloodGroup': '',
      'importantInfo': '',
      'healthConditions': [],
      'allergies': [],
      'medications': [],
      'mobilityNeeds': '',
      'inputPreference': '',
      'voiceAssistantEnabled': false,
      'largeTextEnabled': false,
      'linkedCaregiverUids': [],
      'linkedSeniorUids': [],
      'caregiverCode': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeProfile({
    required String uid,
    required String fullName,
    required String role,
    required String language,
    required String phone,
    required String address,
    required List<Map<String, dynamic>> emergencyContacts,
    String bloodGroup = '',
    String importantInfo = '',
  }) async {
    await _db.collection('users').doc(uid).update({
      'fullName': fullName,
      'role': role,
      'language': language,
      'phone': phone,
      'address': address,
      'emergencyContacts': emergencyContacts,
      'bloodGroup': bloodGroup,
      'importantInfo': importantInfo,
      'profileCompleted': true,
      if (role == 'caregiver') 'questionnaireCompleted': true,
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<AppUser?> getUserByUid(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.data()!);
  }

  Future<List<AppUser>> getUsersByUids(List<String> uids) async {
    final cleaned = uids.where((e) => e.trim().isNotEmpty).toSet().toList();
    if (cleaned.isEmpty) return [];

    final users = <AppUser>[];

    for (final uid in cleaned) {
      final user = await getUserByUid(uid);
      if (user != null) {
        users.add(user);
      }
    }

    return users;
  }

  Future<void> saveQuestionnaire({
    required String uid,
    required String preferredName,
    required String age,
    String bloodGroup = '',
    String importantInfo = '',
    required List<String> healthConditions,
    required List<String> allergies,
    required List<String> medications,
    required String mobilityNeeds,
    required String inputPreference,
    required bool voiceAssistantEnabled,
    required bool largeTextEnabled,
  }) async {
    await _db.collection('users').doc(uid).update({
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
      'questionnaireCompleted': true,
    });
  }

  Future<void> updateHealthInfo({
    required String uid,
    required String preferredName,
    required String age,
    required String bloodGroup,
    required String importantInfo,
    required List<String> healthConditions,
    required List<String> allergies,
    required List<String> medications,
    required String mobilityNeeds,
    required String inputPreference,
    required bool voiceAssistantEnabled,
    required bool largeTextEnabled,
  }) async {
    await _db.collection('users').doc(uid).update({
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
    });
  }

  String _generateRandomCode({int length = 6}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();

    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<String> generateCaregiverCode(String seniorUid) async {
    String code = _generateRandomCode();

    for (int i = 0; i < 5; i++) {
      final existing = await _db
          .collection('users')
          .where('caregiverCode', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await _db.collection('users').doc(seniorUid).update({
          'caregiverCode': code,
        });
        return code;
      }

      code = _generateRandomCode();
    }

    throw Exception('Could not generate a unique caregiver code.');
  }

  Future<String> linkCaregiverToSenior({
    required String caregiverUid,
    required String code,
  }) async {
    final cleanedCode = code.trim().toUpperCase();

    if (cleanedCode.isEmpty) {
      return 'Please enter a caregiver code.';
    }

    final caregiverDoc = await _db.collection('users').doc(caregiverUid).get();
    if (!caregiverDoc.exists || caregiverDoc.data() == null) {
      return 'Caregiver account not found.';
    }

    final caregiverData = caregiverDoc.data()!;

    final caregiverLinkedSeniorUids = List<String>.from(
      caregiverData['linkedSeniorUids'] ??
          ((caregiverData['linkedSeniorUid'] != null &&
                  caregiverData['linkedSeniorUid'].toString().isNotEmpty)
              ? [caregiverData['linkedSeniorUid'].toString()]
              : []),
    );

    final seniorQuery = await _db
        .collection('users')
        .where('caregiverCode', isEqualTo: cleanedCode)
        .where('role', isEqualTo: 'senior')
        .limit(1)
        .get();

    if (seniorQuery.docs.isEmpty) {
      return 'Invalid caregiver code.';
    }

    final seniorDoc = seniorQuery.docs.first;
    final seniorUid = seniorDoc.id;
    final seniorData = seniorDoc.data();

    if (seniorUid == caregiverUid) {
      return 'You cannot link to your own account.';
    }

    if (caregiverLinkedSeniorUids.contains(seniorUid)) {
      return 'You are already linked to this senior.';
    }

    final seniorLinkedCaregiverUids = List<String>.from(
      seniorData['linkedCaregiverUids'] ??
          ((seniorData['linkedCaregiverUid'] != null &&
                  seniorData['linkedCaregiverUid'].toString().isNotEmpty)
              ? [seniorData['linkedCaregiverUid'].toString()]
              : []),
    );

    final batch = _db.batch();

    batch.update(_db.collection('users').doc(caregiverUid), {
      'linkedSeniorUids': FieldValue.arrayUnion([seniorUid]),
      'role': 'caregiver',
      'profileCompleted': true,
      'questionnaireCompleted': true,
    });

    if (!seniorLinkedCaregiverUids.contains(caregiverUid)) {
      batch.update(_db.collection('users').doc(seniorUid), {
        'linkedCaregiverUids': FieldValue.arrayUnion([caregiverUid]),
      });
    }

    await batch.commit();

    final seniorName = (seniorData['fullName'] ?? '').toString().trim();
    return seniorName.isEmpty
        ? 'Senior linked successfully.'
        : 'Linked successfully to $seniorName.';
  }

  Future<String> createCheckOnMeAlert({
    required String seniorUid,
    String message = 'Please check on me.',
  }) async {
    final seniorDoc = await _db.collection('users').doc(seniorUid).get();

    if (!seniorDoc.exists || seniorDoc.data() == null) {
      return 'Senior account not found.';
    }

    final seniorData = seniorDoc.data()!;
    final caregiverUids = List<String>.from(
      seniorData['linkedCaregiverUids'] ??
          ((seniorData['linkedCaregiverUid'] != null &&
                  seniorData['linkedCaregiverUid'].toString().isNotEmpty)
              ? [seniorData['linkedCaregiverUid'].toString()]
              : []),
    );

    if (caregiverUids.isEmpty) {
      return 'No caregiver is linked yet.';
    }

    final seniorName = (seniorData['fullName'] ?? '').toString().trim();

    await _db.collection('alerts').add({
      'seniorUid': seniorUid,
      'seniorName': seniorName.isEmpty ? 'Senior User' : seniorName,
      'caregiverUids': caregiverUids,
      'type': 'check_on_me',
      'message': message,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return 'Caregiver alerted successfully.';
  }

  Stream<List<AlertItem>> getActiveAlertsForCaregiver(String caregiverUid) {
    return _db
        .collection('alerts')
        .where('caregiverUids', arrayContains: caregiverUid)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AlertItem.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> resolveAlert(String alertId) async {
    await _db.collection('alerts').doc(alertId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Medication>> getMedicationsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Medication.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addMedication({
    required String uid,
    required Medication medication,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .add(medication.toMap());
  }

  Future<void> updateMedication({
    required String uid,
    required Medication medication,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .doc(medication.id)
        .update(medication.toMap());
  }

  Future<void> deleteMedication({
    required String uid,
    required String medicationId,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .doc(medicationId)
        .delete();
  }

  Future<Medication?> getMedicationById({
    required String uid,
    required String medicationId,
  }) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .doc(medicationId)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return Medication.fromMap(doc.id, doc.data()!);
  }

  Future<void> addMedicationLog({
    required String uid,
    required String medicationId,
    required MedicationLog log,
  }) async {
    final docRef = _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .doc(medicationId);

    final doc = await docRef.get();
    if (!doc.exists || doc.data() == null) return;

    final medication = Medication.fromMap(doc.id, doc.data()!);
    final updatedLogs = [...medication.logs, log];

    await docRef.update({
      'logs': updatedLogs.map((e) => e.toMap()).toList(),
    });
  }
}