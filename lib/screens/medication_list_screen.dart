import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'add_edit_medication_screen.dart';
import 'medication_detail_screen.dart';

class MedicationListScreen extends StatelessWidget {
  const MedicationListScreen({super.key});

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
        }
      }
    }

    if (nextTime == null || nextName == null) return null;

    return {
      'name': nextName,
      'time': nextTime,
      'dosage': nextDosage ?? '',
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
            return const Center(child: CircularProgressIndicator());
          }

          final medications = snapshot.data ?? [];

          if (medications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 80,
                      color: Colors.teal.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No medications yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tap the button below to add your first medication.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: med.isActive
                              ? Colors.teal.shade100
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: med.isActive
                                  ? Colors.teal.shade50
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.medication,
                              color: med.isActive
                                  ? Colors.teal
                                  : Colors.grey.shade600,
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
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  med.dosage,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: med.scheduleTimes.map<Widget>((time) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        time,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
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
                                    color: Colors.blueGrey.shade50,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    formatRepeatDays(med.repeatDays),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey.shade700,
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
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  med.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: med.isActive
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Icon(Icons.chevron_right),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditMedicationScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Medication'),
      ),
    );
  }
}