import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'add_edit_medication_screen.dart';
import 'add_prescription_screen.dart';
import 'medication_detail_screen.dart';

class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({super.key});

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  bool _fabExpanded = false;

  String formatRepeatDays(List<String> days) {
    if (days.isEmpty) return 'No repeat days';
    if (days.length == 7) return 'Every day';
    return days.join(', ');
  }

  DateTime? _parseMedicationTime(String time) {
    final raw = time.trim().toLowerCase();

    try {
      if (raw.contains('am') || raw.contains('pm')) {
        final cleaned = raw.replaceAll('.', '').trim();
        final parts = cleaned.split(' ');
        if (parts.length != 2) return null;

        final timePart = parts[0];
        final meridiem = parts[1];
        final hm = timePart.split(':');

        int hour = int.parse(hm[0]);
        final minute = hm.length > 1 ? int.parse(hm[1]) : 0;

        if (meridiem == 'pm' && hour != 12) hour += 12;
        if (meridiem == 'am' && hour == 12) hour = 0;

        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }

      final hm = raw.split(':');
      if (hm.length < 2) return null;

      final hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String _formatDisplayTime(DateTime dt) {
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$hour:$minute $suffix';
  }

  String _formatDueIn(DateTime nextTime) {
    final now = DateTime.now();
    final diff = nextTime.difference(now);

    if (diff.inMinutes <= 0) return 'Due now';

    if (diff.inHours >= 1) {
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      if (mins == 0) {
        return 'Due in $hours hr${hours == 1 ? '' : 's'}';
      }
      return 'Due in $hours hr $mins min';
    }

    return 'Due in ${diff.inMinutes} min';
  }

  Map<String, dynamic>? _getNextMedication(List<dynamic> medications) {
    final now = DateTime.now();

    String? nextName;
    DateTime? nextTime;
    String? nextDosage;
    String? nextPhotoBase64;

    for (final med in medications) {
      if (med.isActive != true) continue;

      for (final schedule in med.scheduleTimes) {
        final parsed = _parseMedicationTime(schedule);
        if (parsed == null) continue;

        DateTime candidate = parsed;
        if (candidate.isBefore(now)) {
          candidate = candidate.add(const Duration(days: 1));
        }

        if (nextTime == null || candidate.isBefore(nextTime)) {
          nextTime = candidate;
          nextName = med.name;
          nextDosage = med.dosage;
          nextPhotoBase64 = med.photoBase64 as String? ?? '';
        }
      }
    }

    if (nextTime == null || nextName == null) return null;

    return {
      'name': nextName,
      'time': nextTime,
      'dosage': nextDosage ?? '',
      'photoBase64': nextPhotoBase64 ?? '',
    };
  }

  Widget _buildSummaryCard(List<dynamic> medications) {
    final activeMeds = medications.where((med) => med.isActive == true).toList();
    final int totalActive = activeMeds.length;

    final int totalDosesToday = activeMeds.isEmpty
        ? 0
        : activeMeds
            .map<int>((med) => med.scheduleTimes.length)
            .fold<int>(0, (int sum, int count) => sum + count);

    final nextMedication = _getNextMedication(activeMeds);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.medication_outlined,
                color: Color(0xFF111827),
                size: 26,
              ),
              SizedBox(width: 10),
              Text(
                'Medication Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (nextMedication != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((nextMedication['photoBase64'] as String).isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(nextMedication['photoBase64'] as String),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Next up',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nextMedication['name'] as String,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if ((nextMedication['dosage'] as String).trim().isNotEmpty)
                          Text(
                            nextMedication['dosage'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _miniPill(
                              _formatDueIn(nextMedication['time'] as DateTime),
                            ),
                            _miniPill(
                              'Next at ${_formatDisplayTime(nextMedication['time'] as DateTime)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'No upcoming medication right now.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  value: '$totalActive',
                  label: 'Active',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statBox(
                  value: '$totalDosesToday',
                  label: 'Scheduled Today',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _miniPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  static Widget _statBox({
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableFab(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          _fabOption(
            context,
            icon: Icons.document_scanner_outlined,
            label: 'Add Prescription',
            onTap: () {
              setState(() => _fabExpanded = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddPrescriptionScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _fabOption(
            context,
            icon: Icons.medication_outlined,
            label: 'Add Medication',
            onTap: () {
              setState(() => _fabExpanded = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditMedicationScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
        ],
        FloatingActionButton(
          backgroundColor: const Color(0xFF4F8CFF),
          foregroundColor: Colors.white,
          onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _fabOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF4F8CFF)),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Medications',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: FirestoreService().getMedicationsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4F8CFF)),
                  SizedBox(height: 14),
                  Text(
                    'Loading medications...',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
                  ),
                ],
              ),
            );
          }

          final medications = snapshot.data ?? [];

          if (medications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medication_outlined,
                        size: 56,
                        color: Color(0xFF4F8CFF),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No medications yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Add your medications to get daily reminders and track your adherence.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddEditMedicationScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'Add First Medication',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F8CFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildSummaryCard(medications),
              ...List.generate(medications.length, (index) {
                final med = medications[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MedicationDetailScreen(medicationId: med.id),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: med.isActive
                              ? const Color(0xFFBFE0FF)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (med.photoBase64.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(
                                base64Decode(med.photoBase64),
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: med.isActive
                                    ? const Color(0xFFEFF4FF)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.medication,
                                color: med.isActive
                                    ? const Color(0xFF4F8CFF)
                                    : const Color(0xFF6B7280),
                                size: 28,
                              ),
                            ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  med.name,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  med.dosage,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      med.scheduleTimes.map<Widget>((time) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF4FF),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        time,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2354B8),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    formatRepeatDays(med.repeatDays),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: med.isActive
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  med.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: med.isActive
                                        ? const Color(0xFF065F46)
                                        : const Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF9CA3AF),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: _buildExpandableFab(context),
      bottomNavigationBar: const CustomBottomNavBar(
        currentTab: AppTab.health,
      ),
    );
  }
}