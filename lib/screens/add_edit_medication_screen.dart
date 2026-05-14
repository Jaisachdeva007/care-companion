import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/medication.dart';
import '../services/ai_service.dart';
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
  final notesController = TextEditingController();

  List<TimeOfDay> _scheduleTimes = [];
  String _repeatType = 'daily';
  int _repeatInterval = 2;
  List<String> _selectedDays = ['Mon'];
  bool isActive = true;
  bool isSaving = false;
  bool _isScanning = false;
  DateTime? _refillDate;
  String _photoBase64 = '';

  static const _allDays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  static const _repeatOptions = [
    ('daily', 'Every day'),
    ('specific_days', 'Specific days of the week'),
    ('every_x_days', 'Every X days'),
    ('weekly', 'Weekly'),
    ('biweekly', 'Every 2 weeks'),
    ('monthly', 'Monthly'),
  ];

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    if (med != null) {
      nameController.text = med.name;
      dosageController.text = med.dosage;
      notesController.text = med.notes;
      isActive = med.isActive;
      _refillDate = med.refillDate;
      _repeatType = med.repeatType.isEmpty ? 'daily' : med.repeatType;
      _repeatInterval = med.repeatInterval > 1 ? med.repeatInterval : 2;
      _photoBase64 = med.photoBase64;
      _selectedDays = med.repeatDays.isNotEmpty
          ? List.from(med.repeatDays)
          : ['Mon'];

      for (final t in med.scheduleTimes) {
        final tod = _parseTimeString(t);
        if (tod != null) _scheduleTimes.add(tod);
      }
    }

    if (_scheduleTimes.isEmpty) {
      _scheduleTimes.add(const TimeOfDay(hour: 8, minute: 0));
    }
  }

  TimeOfDay? _parseTimeString(String t) {
    try {
      final clean = t.trim().toLowerCase().replaceAll('.', '');
      if (clean.contains('am') || clean.contains('pm')) {
        final parts = clean.split(' ');
        if (parts.length < 2) return null;
        final hm = parts[0].split(':');
        int hour = int.parse(hm[0]);
        final minute = hm.length > 1 ? int.parse(hm[1]) : 0;
        if (parts[1] == 'pm' && hour != 12) hour += 12;
        if (parts[1] == 'am' && hour == 12) hour = 0;
        return TimeOfDay(hour: hour, minute: minute);
      }
      final hm = clean.split(':');
      if (hm.length < 2) return null;
      return TimeOfDay(hour: int.parse(hm[0]), minute: int.parse(hm[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  String _formatTime24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduleTimes.isNotEmpty
          ? _scheduleTimes.last
          : const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _scheduleTimes.add(picked));
    }
  }

  Future<void> _pickRefillDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _refillDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _refillDate = picked);
    }
  }

  Future<void> _pickAndScanPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64 = base64Encode(bytes);
    final mimeType = (bytes.length >= 4 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47)
        ? 'image/png'
        : 'image/jpeg';
    setState(() {
      _photoBase64 = base64;
      _isScanning = true;
    });

    try {
      final result =
          await AiService().scanMedicationImage(base64, mimeType: mimeType);
      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read medication details from image.')),
        );
        return;
      }

      setState(() {
        if (result['name']!.isNotEmpty) nameController.text = result['name']!;
        if (result['dosage']!.isNotEmpty) dosageController.text = result['dosage']!;
        if (result['notes']!.isNotEmpty) notesController.text = result['notes']!;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Details filled from image — please review and confirm.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  List<String> _buildRepeatDays() {
    switch (_repeatType) {
      case 'daily':
      case 'every_x_days':
      case 'monthly':
        return List.from(_allDays);
      case 'specific_days':
        return List.from(_selectedDays);
      case 'weekly':
      case 'biweekly':
        return [_selectedDays.isNotEmpty ? _selectedDays.first : 'Mon'];
      default:
        return List.from(_allDays);
    }
  }

  Future<void> saveMedication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduleTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add at least one schedule time'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFD97706),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final med = Medication(
        id: widget.medication?.id ?? '',
        name: nameController.text.trim(),
        dosage: dosageController.text.trim(),
        scheduleTimes: _scheduleTimes.map(_formatTime24).toList(),
        repeatDays: _buildRepeatDays(),
        repeatType: _repeatType,
        repeatInterval: _repeatType == 'every_x_days' ? _repeatInterval : 1,
        notes: notesController.text.trim(),
        refillDate: _refillDate,
        isActive: isActive,
        logs: widget.medication?.logs ?? [],
        photoBase64: _photoBase64,
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
        SnackBar(
          content: Text('Could not save medication: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    notesController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF6B7280)) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF4F8CFF), width: 1.5),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return _sectionCard(
      title: 'Medication Photo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Take a photo of your medication label and let AI fill in the details automatically.',
            style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_photoBase64.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(_photoBase64),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              if (_photoBase64.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isScanning ? null : _pickAndScanPhoto,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4F8CFF),
                              ),
                            )
                          : const Icon(Icons.camera_alt_outlined, size: 18),
                      label: Text(
                        _isScanning
                            ? 'Scanning...'
                            : _photoBase64.isEmpty
                                ? 'Upload & Scan with AI'
                                : 'Rescan with AI',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F8CFF),
                        side: const BorderSide(color: Color(0xFF4F8CFF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    if (_photoBase64.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _photoBase64 = ''),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9CA3AF),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Remove photo'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimesSection() {
    return _sectionCard(
      title: 'Schedule Times',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_scheduleTimes.isEmpty)
            const Text(
              'No times added yet.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _scheduleTimes.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFD6E6FF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 18,
                        color: Color(0xFF4F8CFF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(t),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() => _scheduleTimes.removeAt(i));
                        },
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Time'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4F8CFF),
              side: const BorderSide(color: Color(0xFF4F8CFF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencySection() {
    return _sectionCard(
      title: 'Frequency',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _repeatType,
            decoration: _inputDecoration('How often?'),
            items: _repeatOptions.map((opt) {
              return DropdownMenuItem(value: opt.$1, child: Text(opt.$2));
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _repeatType = value);
            },
          ),
          if (_repeatType == 'specific_days') ...[
            const SizedBox(height: 14),
            const Text(
              'Select days:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allDays.map((day) {
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      if (isSelected) {
                        if (_selectedDays.length > 1) {
                          _selectedDays.remove(day);
                        }
                      } else {
                        _selectedDays.add(day);
                      }
                    });
                  },
                  selectedColor: const Color(0xFFEFF4FF),
                  checkmarkColor: const Color(0xFF2354B8),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF374151),
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF4F8CFF)
                        : const Color(0xFFE5E7EB),
                  ),
                );
              }).toList(),
            ),
          ],
          if (_repeatType == 'every_x_days') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Repeat every',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 12),
                _buildStepper(),
                const SizedBox(width: 12),
                const Text(
                  'days',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ],
          if (_repeatType == 'weekly' || _repeatType == 'biweekly') ...[
            const SizedBox(height: 14),
            Text(
              _repeatType == 'weekly'
                  ? 'Which day of the week?'
                  : 'Which day (every 2 weeks)?',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allDays.map((day) {
                final isSelected = _selectedDays.isNotEmpty &&
                    _selectedDays.first == day;
                return ChoiceChip(
                  label: Text(day),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedDays = [day]);
                  },
                  selectedColor: const Color(0xFFEFF4FF),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF374151),
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF4F8CFF)
                        : const Color(0xFFE5E7EB),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
            onTap: () {
              if (_repeatInterval > 2) {
                setState(() => _repeatInterval--);
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Icon(Icons.remove, size: 22, color: Color(0xFF6B7280)),
            ),
          ),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$_repeatInterval',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          InkWell(
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(12),
            ),
            onTap: () {
              if (_repeatInterval < 30) {
                setState(() => _repeatInterval++);
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Icon(Icons.add, size: 22, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medication != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Medication' : 'Add Medication',
          style: const TextStyle(
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildPhotoSection(),
              _sectionCard(
                title: 'Medication Details',
                child: Column(
                  children: [
                    TextFormField(
                      controller: nameController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter medication name' : null,
                      decoration: _inputDecoration(
                        'Medication Name',
                        icon: Icons.medication_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: dosageController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter dosage' : null,
                      decoration: _inputDecoration(
                        'Dosage',
                        hint: 'e.g. 1 tablet, 5 ml, 500 mg',
                        icon: Icons.science_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTimesSection(),
              _buildFrequencySection(),
              _sectionCard(
                title: 'Additional Details',
                child: Column(
                  children: [
                    TextFormField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        'Notes',
                        hint: 'Take with food, avoid alcohol, etc.',
                        icon: Icons.notes,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _pickRefillDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Refill Date',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  Text(
                                    _refillDate != null
                                        ? '${_refillDate!.year}-${_refillDate!.month.toString().padLeft(2, '0')}-${_refillDate!.day.toString().padLeft(2, '0')}'
                                        : 'Tap to set a refill date',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _refillDate != null
                                          ? const Color(0xFF111827)
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          'Active medication',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        subtitle: const Text(
                          'Enable reminders for this medication',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        value: isActive,
                        activeColor: const Color(0xFF4F8CFF),
                        onChanged: (v) => setState(() => isActive = v),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveMedication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F8CFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Save Changes' : 'Add Medication',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
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
