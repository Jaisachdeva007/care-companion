import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../services/firestore_service.dart';
import 'add_edit_medication_screen.dart';
import 'medication_history_screen.dart';

class MedicationDetailScreen extends StatefulWidget {
  final String medicationId;

  const MedicationDetailScreen({super.key, required this.medicationId});

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  Medication? medication;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMedication();
  }

  Future<void> loadMedication() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final med = await FirestoreService().getMedicationById(
      uid: uid,
      medicationId: widget.medicationId,
    );

    setState(() {
      medication = med;
      isLoading = false;
    });
  }

  Future<void> markStatus(String status) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirestoreService().addMedicationLog(
      uid: uid,
      medicationId: widget.medicationId,
      log: MedicationLog(
        scheduledTime: DateTime.now(),
        actionTime: DateTime.now(),
        status: status,
      ),
    );
    await loadMedication();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (medication == null) {
      return const Scaffold(body: Center(child: Text('Medication not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(medication!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditMedicationScreen(medication: medication),
                ),
              );
              await loadMedication();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dosage: ${medication!.dosage}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Schedule: ${medication!.scheduleTimes.join(", ")}'),
            const SizedBox(height: 8),
            Text('Notes: ${medication!.notes.isEmpty ? "None" : medication!.notes}'),
            const SizedBox(height: 8),
            Text('Refill Date: ${medication!.refillDate?.toIso8601String().split("T").first ?? "Not set"}'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => markStatus('taken'),
                    child: const Text('Mark Taken'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => markStatus('skipped'),
                    child: const Text('Skip'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Taken / Missed History'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MedicationHistoryScreen(
                      medicationId: medication!.id,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}