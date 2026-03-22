import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'add_edit_medication_screen.dart';
import 'medication_detail_screen.dart';

class MedicationListScreen extends StatelessWidget {
  const MedicationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medications'),
      ),
      body: StreamBuilder(
        stream: FirestoreService().getMedicationsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final medications = snapshot.data ?? [];

          if (medications.isEmpty) {
            return const Center(
              child: Text('No medications added yet.'),
            );
          }

          return ListView.builder(
            itemCount: medications.length,
            itemBuilder: (context, index) {
              final med = medications[index];
              return ListTile(
                title: Text(med.name),
                subtitle: Text('${med.dosage} • ${med.scheduleTimes.join(", ")}'),
                trailing: Icon(
                  med.isActive ? Icons.check_circle : Icons.cancel,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MedicationDetailScreen(medicationId: med.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditMedicationScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}