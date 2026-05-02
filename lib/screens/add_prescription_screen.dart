import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/medication.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class AddPrescriptionScreen extends StatefulWidget {
  const AddPrescriptionScreen({super.key});

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  String _prescriptionPhotoBase64 = '';
  bool _isScanning = false;
  bool _isSaving = false;
  List<_ReviewMedication> _medications = [];

  Future<void> _pickPrescription() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
      maxHeight: 1600,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64 = base64Encode(bytes);

    setState(() {
      _prescriptionPhotoBase64 = base64;
      _isScanning = true;
      _medications = [];
    });

    try {
      final results = await AiService().scanPrescriptionImage(base64);
      if (!mounted) return;

      if (results == null || results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No medications found in the image. Try a clearer photo.'),
          ),
        );
        setState(() => _isScanning = false);
        return;
      }

      setState(() {
        _medications = results
            .map((scanned) => _ReviewMedication.fromScanned(scanned))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _saveAll() async {
    final toSave = _medications.where((m) => m.include).toList();
    if (toSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one medication to add.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final service = FirestoreService();

      for (final review in toSave) {
        final med = Medication(
          id: '',
          name: review.nameController.text.trim(),
          dosage: review.dosageController.text.trim(),
          scheduleTimes: const ['08:00'],
          repeatDays: const [
            'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
          ],
          repeatType: 'daily',
          repeatInterval: 1,
          notes: review.notesController.text.trim(),
          refillDate: null,
          isActive: true,
          logs: const [],
          photoBase64: _prescriptionPhotoBase64,
        );

        await service.addMedication(uid: uid, medication: med);
        await NotificationService().scheduleMedicationTimes(
          medicationName: med.name,
          dosage: med.dosage,
          scheduleTimes: med.scheduleTimes,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${toSave.length} medication${toSave.length == 1 ? '' : 's'} added.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final m in _medications) {
      m.nameController.dispose();
      m.dosageController.dispose();
      m.notesController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Add Prescription',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUploadCard(),
            if (_medications.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildMedicationReviewHeader(),
              const SizedBox(height: 12),
              ..._medications.asMap().entries.map(
                (entry) => _buildReviewCard(entry.key, entry.value),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: _medications.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _isSaving ? const Color(0xFF9CA3AF) : const Color(0xFF4F8CFF),
              foregroundColor: Colors.white,
              onPressed: _isSaving ? null : _saveAll,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _isSaving
                    ? 'Adding...'
                    : 'Add ${_medications.where((m) => m.include).length} Medication${_medications.where((m) => m.include).length == 1 ? '' : 's'}',
              ),
            ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prescription Photo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload a photo of the prescription and AI will extract all listed medications for you to review.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          if (_prescriptionPhotoBase64.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(_prescriptionPhotoBase64),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _pickPrescription,
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.document_scanner_outlined, size: 20),
              label: Text(
                _isScanning
                    ? 'Scanning prescription...'
                    : _prescriptionPhotoBase64.isEmpty
                        ? 'Upload Prescription'
                        : 'Upload Different Prescription',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F8CFF),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationReviewHeader() {
    final count = _medications.length;
    return Row(
      children: [
        const Icon(Icons.fact_check_outlined, size: 20, color: Color(0xFF4F8CFF)),
        const SizedBox(width: 8),
        Text(
          'Found $count medication${count == 1 ? '' : 's'} — review before adding',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(int index, _ReviewMedication med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: med.include
              ? const Color(0xFFBFE0FF)
              : const Color(0xFFE5E7EB),
          width: med.include ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: med.include
                      ? const Color(0xFFEFF4FF)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.medication,
                  color: med.include
                      ? const Color(0xFF4F8CFF)
                      : const Color(0xFF9CA3AF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Medication ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              Transform.scale(
                scale: 1.1,
                child: Checkbox(
                  value: med.include,
                  activeColor: const Color(0xFF4F8CFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (v) => setState(() => med.include = v ?? true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildReviewField(
            controller: med.nameController,
            label: 'Medication Name',
            icon: Icons.medication_outlined,
            enabled: med.include,
          ),
          const SizedBox(height: 10),
          _buildReviewField(
            controller: med.dosageController,
            label: 'Dosage',
            icon: Icons.science_outlined,
            enabled: med.include,
          ),
          const SizedBox(height: 10),
          _buildReviewField(
            controller: med.notesController,
            label: 'Notes / Instructions',
            icon: Icons.notes,
            enabled: med.include,
            maxLines: 2,
          ),
          if (med.frequency.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Frequency: ${med.frequency}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (med.duration.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Duration: ${med.duration}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 14,
        color: enabled ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4F8CFF), width: 1.5),
        ),
      ),
    );
  }
}

class _ReviewMedication {
  final TextEditingController nameController;
  final TextEditingController dosageController;
  final TextEditingController notesController;
  final String frequency;
  final String duration;
  bool include;

  _ReviewMedication({
    required this.nameController,
    required this.dosageController,
    required this.notesController,
    required this.frequency,
    required this.duration,
    this.include = true,
  });

  factory _ReviewMedication.fromScanned(ScannedMedication scanned) {
    return _ReviewMedication(
      nameController: TextEditingController(text: scanned.name),
      dosageController: TextEditingController(text: scanned.dosage),
      notesController: TextEditingController(text: scanned.notes),
      frequency: scanned.frequency,
      duration: scanned.duration,
    );
  }
}
