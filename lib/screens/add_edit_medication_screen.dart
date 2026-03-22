import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class AddEditMedicationScreen extends StatefulWidget {
  final Medication? medication;

  const AddEditMedicationScreen({super.key, this.medication});

  @override
  State<AddEditMedicationScreen> createState() =>
      _AddEditMedicationScreenState();
}

class _AddEditMedicationScreenState extends State<AddEditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final dosageController = TextEditingController();
  final scheduleTimesController = TextEditingController();
  final notesController = TextEditingController();
  final refillDateController = TextEditingController();

  bool isActive = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    if (med != null) {
      nameController.text = med.name;
      dosageController.text = med.dosage;
      scheduleTimesController.text = med.scheduleTimes.join(', ');
      notesController.text = med.notes;
      refillDateController.text = med.refillDate != null
          ? med.refillDate!.toIso8601String().split('T').first
          : '';
      isActive = med.isActive;
    }
  }

  Future<void> saveMedication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final scheduleTimes = scheduleTimesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final refillDate = refillDateController.text.trim().isEmpty
          ? null
          : DateTime.tryParse(refillDateController.text.trim());

      final med = Medication(
        id: widget.medication?.id ?? '',
        name: nameController.text.trim(),
        dosage: dosageController.text.trim(),
        scheduleTimes: scheduleTimes,
        notes: notesController.text.trim(),
        refillDate: refillDate,
        isActive: isActive,
        logs: widget.medication?.logs ?? [],
      );

      if (widget.medication == null) {
        await FirestoreService().addMedication(uid: uid, medication: med);
      } else {
        await FirestoreService().updateMedication(uid: uid, medication: med);
      }

      if (isActive) {
        await NotificationService().scheduleMedicationTimes(
          medicationName: med.name,
          dosage: med.dosage,
          scheduleTimes: med.scheduleTimes,
        );

        if (med.refillDate != null) {
          await NotificationService().scheduleRefillReminder(
            medicationName: med.name,
            refillDate: med.refillDate!,
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save medication: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (value) {
          if ((label == 'Medication Name' || label == 'Dosage') &&
              (value == null || value.trim().isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    scheduleTimesController.dispose();
    notesController.dispose();
    refillDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medication != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medication' : 'Add Medication'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medication, size: 34, color: Colors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing
                            ? 'Update medication details and reminder times.'
                            : 'Add a medication and set reminder times.',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              buildField(
                nameController,
                'Medication Name',
                icon: Icons.badge_outlined,
              ),
              buildField(
                dosageController,
                'Dosage',
                hint: 'e.g. 1 pill, 5 ml, 500 mg',
                icon: Icons.science_outlined,
              ),
              buildField(
                scheduleTimesController,
                'Schedule Times',
                hint: 'e.g. 08:00, 20:00',
                icon: Icons.access_time,
              ),
              buildField(
                notesController,
                'Notes',
                hint: 'Optional notes',
                maxLines: 3,
                icon: Icons.notes,
              ),
              buildField(
                refillDateController,
                'Refill Date',
                hint: 'YYYY-MM-DD',
                icon: Icons.calendar_today_outlined,
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Active medication',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Enable reminders for this medication'),
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveMedication,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSaving
                      ? const CircularProgressIndicator()
                      : Text(
                          isEditing ? 'Save Changes' : 'Add Medication',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}