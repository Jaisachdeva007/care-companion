import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class MedicationHistoryScreen extends StatelessWidget {
  final String medicationId;

  const MedicationHistoryScreen({super.key, required this.medicationId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication History'),
      ),
      body: FutureBuilder(
        future: FirestoreService().getMedicationById(
          uid: uid,
          medicationId: medicationId,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final medication = snapshot.data;
          if (medication == null || medication.logs.isEmpty) {
            return const Center(child: Text('No history yet'));
          }

          final logs = medication.logs.reversed.toList();

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                title: Text(log.status.toUpperCase()),
                subtitle: Text(
                  'Scheduled: ${log.scheduledTime}\n'
                  'Action: ${log.actionTime ?? "No action time"}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}