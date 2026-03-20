import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createBasicUser({
    required String uid,
    required String email,
  }) async {
    final doc = _db.collection('users').doc(uid);

    final snapshot = await doc.get();
    if (snapshot.exists) return;

    await doc.set({
      'uid': uid,
      'email': email,
      'fullName': '',
      'role': 'senior',
      'language': '',
      'phone': '',
      'address': '',
      'emergencyContacts': [],
      'profileCompleted': false,
      'questionnaireCompleted': false,
      'preferredName': '',
      'age': '',
      'healthConditions': [],
      'allergies': [],
      'medications': [],
      'mobilityNeeds': '',
      'inputPreference': '',
      'voiceAssistantEnabled': false,
      'largeTextEnabled': false,
      'linkedCaregiverUid': null,
      'linkedSeniorUid': null,
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
  }) async {
    await _db.collection('users').doc(uid).update({
      'fullName': fullName,
      'role': role,
      'language': language,
      'phone': phone,
      'address': address,
      'emergencyContacts': emergencyContacts,
      'profileCompleted': true,
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

  Future<void> sendCaregiverInvite({
    required String fromUid,
    required String fromEmail,
    required String toEmail,
  }) async {
    await _db.collection('connection_requests').add({
      'fromUid': fromUid,
      'fromEmail': fromEmail,
      'toEmail': toEmail.trim().toLowerCase(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingInvitesForEmail(
    String email,
  ) {
    return _db
        .collection('connection_requests')
        .where('toEmail', isEqualTo: email.trim().toLowerCase())
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> acceptInvite({
    required String requestId,
    required String caregiverUid,
  }) async {
    final requestDoc =
        await _db.collection('connection_requests').doc(requestId).get();

    if (!requestDoc.exists || requestDoc.data() == null) return;

    final data = requestDoc.data()!;
    final seniorUid = data['fromUid'] as String;

    final batch = _db.batch();

    final seniorRef = _db.collection('users').doc(seniorUid);
    final caregiverRef = _db.collection('users').doc(caregiverUid);
    final requestRef = _db.collection('connection_requests').doc(requestId);

    batch.update(seniorRef, {
      'linkedCaregiverUid': caregiverUid,
    });

    batch.update(caregiverRef, {
      'linkedSeniorUid': seniorUid,
      'role': 'caregiver',
    });

    batch.update(requestRef, {
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> declineInvite(String requestId) async {
    await _db.collection('connection_requests').doc(requestId).update({
      'status': 'declined',
    });
  }
  Future<void> saveQuestionnaire({
  required String uid,
  required String preferredName,
  required String age,
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
}