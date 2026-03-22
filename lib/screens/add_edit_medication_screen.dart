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

  Widget buildField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: (value) {
          if ((label == 'Medication Name' || label == 'Dosage') &&
              (value == null || value.trim().isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              buildField(nameController, 'Medication Name'),
              buildField(dosageController, 'Dosage'),
              buildField(
                scheduleTimesController,
                'Schedule Times (comma separated, e.g. 08:00, 20:00)',
              ),
              buildField(notesController, 'Notes'),
              buildField(refillDateController, 'Refill Date (YYYY-MM-DD)'),
              SwitchListTile(
                title: const Text('Active'),
                value: isActive,
                onChanged: (value) {
                  setState(() {
                    isActive = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveMedication,
                  child: isSaving
                      ? const CircularProgressIndicator()
                      : Text(isEditing ? 'Save Changes' : 'Add Medication'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}