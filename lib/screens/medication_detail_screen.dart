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

  String formatRepeatDays(List<String> days) {
    if (days.isEmpty) return 'No repeat days set';
    if (days.length == 7) return 'Every day';
    return days.join(', ');
  }

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

    if (!mounted) return;

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

    if (!mounted) return;

    final message =
        status == 'taken' ? 'Marked as taken' : 'Marked as skipped';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> deleteMedication() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Medication'),
          content: const Text(
            'Are you sure you want to delete this medication?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirestoreService().deleteMedication(
      uid: uid,
      medicationId: widget.medicationId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medication deleted')),
    );

    Navigator.pop(context);
  }

  Widget infoCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (medication == null) {
      return const Scaffold(
        body: Center(child: Text('Medication not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(medication!.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditMedicationScreen(
                    medication: medication,
                  ),
                ),
              );
              await loadMedication();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: deleteMedication,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.teal.shade600],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Icon(Icons.medication, color: Colors.white, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    medication!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      medication!.isActive ? 'Active' : 'Inactive',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            infoCard(
              icon: Icons.science_outlined,
              title: 'Dosage',
              child: Text(
                medication!.dosage,
                style: const TextStyle(fontSize: 17),
              ),
            ),
            infoCard(
              icon: Icons.access_time,
              title: 'Schedule',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: medication!.scheduleTimes.map((time) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ),
            infoCard(
              icon: Icons.repeat,
              title: 'Repeat Days',
              child: Text(
                formatRepeatDays(medication!.repeatDays),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            infoCard(
              icon: Icons.notes,
              title: 'Notes',
              child: Text(
                medication!.notes.isEmpty ? 'No notes added' : medication!.notes,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            infoCard(
              icon: Icons.calendar_today_outlined,
              title: 'Refill Date',
              child: Text(
                medication!.refillDate?.toIso8601String().split('T').first ??
                    'Not set',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => markStatus('taken'),
                    icon: const Icon(Icons.check),
                    label: const Text('Mark Taken'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => markStatus('skipped'),
                    icon: const Icon(Icons.close),
                    label: const Text('Skip'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: const Icon(Icons.history),
                title: const Text(
                  'Taken / Missed History',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
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
            ),
          ],
        ),
      ),
    );
  }
}