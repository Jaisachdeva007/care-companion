import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_user.dart';
import '../models/medication.dart';
import '../services/firestore_service.dart';

class SeniorDetailScreen extends StatefulWidget {
  final AppUser senior;

  const SeniorDetailScreen({super.key, required this.senior});

  @override
  State<SeniorDetailScreen> createState() => _SeniorDetailScreenState();
}

class _SeniorDetailScreenState extends State<SeniorDetailScreen> {
  List<Medication> _medications = [];
  bool _loadingMeds = true;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    final stream =
        FirestoreService().getMedicationsStream(widget.senior.uid);
    final meds = await stream.first;
    if (!mounted) return;
    setState(() {
      _medications = meds;
      _loadingMeds = false;
    });
  }

  // Build a 7-day adherence map: { 'Mon Apr 28': {'taken': 2, 'skipped': 1} }
  Map<String, Map<String, int>> _buildAdherenceData() {
    final today = DateTime.now();
    final result = <String, Map<String, int>>{};
    final dayLabels = <String>[];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final label =
          '${_weekdayShort(day.weekday)}\n${day.month}/${day.day}';
      dayLabels.add(label);
      result[label] = {'taken': 0, 'skipped': 0};
    }

    for (final med in _medications) {
      for (final log in med.logs) {
        final diff = today.difference(log.scheduledTime).inDays;
        if (diff < 0 || diff > 6) continue;
        final day = today.subtract(Duration(days: diff));
        final label =
            '${_weekdayShort(day.weekday)}\n${day.month}/${day.day}';
        if (result.containsKey(label)) {
          if (log.status == 'taken') {
            result[label]!['taken'] = (result[label]!['taken'] ?? 0) + 1;
          } else if (log.status == 'skipped') {
            result[label]!['skipped'] = (result[label]!['skipped'] ?? 0) + 1;
          }
        }
      }
    }

    return Map.fromEntries(
      dayLabels.map((k) => MapEntry(k, result[k]!)),
    );
  }

  String _weekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    final senior = widget.senior;
    final adherence = _buildAdherenceData();
    final maxVal = adherence.values
        .map((d) => (d['taken'] ?? 0) + (d['skipped'] ?? 0))
        .fold(0, (a, b) => a > b ? a : b);

    final totalTaken = adherence.values
        .fold(0, (sum, d) => sum + (d['taken'] ?? 0));
    final totalAll = adherence.values
        .fold(0, (sum, d) => sum + (d['taken'] ?? 0) + (d['skipped'] ?? 0));
    final adherencePct = totalAll > 0
        ? ((totalTaken / totalAll) * 100).round()
        : null;

    final displayName = senior.fullName.isEmpty ? 'Senior' : senior.fullName;
    final bloodGroup =
        senior.bloodGroup.isEmpty ? 'Not set' : senior.bloodGroup;
    final allergies =
        senior.allergies.isEmpty ? 'None' : senior.allergies.join(', ');
    final conditions = senior.healthConditions.isEmpty
        ? 'None'
        : senior.healthConditions.join(', ');
    final importantInfo =
        senior.importantInfo.isEmpty ? 'None' : senior.importantInfo;
    final mobilityNeeds =
        senior.mobilityNeeds.isEmpty ? 'None' : senior.mobilityNeeds;

    String emergencyContact = 'Not added';
    if (senior.emergencyContacts.isNotEmpty) {
      final c = senior.emergencyContacts.first;
      final name = (c['name'] ?? '').toString();
      final phone = (c['phone'] ?? '').toString();
      if (name.isNotEmpty || phone.isNotEmpty) {
        emergencyContact = phone.isEmpty ? name : '$name • $phone';
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          displayName,
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(senior, displayName, bloodGroup),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Health Information',
              icon: Icons.health_and_safety_outlined,
              children: [
                _infoRow('Blood Group', bloodGroup),
                _infoRow('Allergies', allergies),
                _infoRow('Conditions', conditions),
                _infoRow('Important Info', importantInfo),
                _infoRow('Mobility Needs', mobilityNeeds),
                _infoRow('Emergency Contact', emergencyContact),
              ],
            ),
            const SizedBox(height: 16),
            _buildAdherenceChart(adherence, maxVal, adherencePct),
            const SizedBox(height: 16),
            _buildMedicationsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      AppUser senior, String displayName, String bloodGroup) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFEFF4FF),
            backgroundImage: senior.photoBase64.isNotEmpty
                ? MemoryImage(base64Decode(senior.photoBase64))
                : null,
            child: senior.photoBase64.isEmpty
                ? const Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: Color(0xFF4F8CFF),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip(Icons.badge_outlined, 'Senior'),
                    _chip(Icons.bloodtype_outlined, bloodGroup),
                    if (senior.age.isNotEmpty)
                      _chip(Icons.cake_outlined, 'Age ${senior.age}'),
                  ],
                ),
                if (senior.phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => launchUrl(
                        Uri(scheme: 'tel', path: senior.phone)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined,
                            size: 18, color: Color(0xFF4F8CFF)),
                        const SizedBox(width: 6),
                        Text(
                          senior.phone,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF4F8CFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4B5563)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Icon(icon, size: 22, color: const Color(0xFF4F8CFF)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceChart(
      Map<String, Map<String, int>> adherence, int maxVal, int? adherencePct) {
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
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  size: 20, color: Color(0xFF4F8CFF)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '7-Day Adherence',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (adherencePct != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _adherenceColor(adherencePct)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$adherencePct%',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _adherenceColor(adherencePct),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(const Color(0xFF22C55E), 'Taken'),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFEF4444), 'Skipped'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: adherence.entries.map((entry) {
                final taken = entry.value['taken'] ?? 0;
                final skipped = entry.value['skipped'] ?? 0;
                final total = taken + skipped;
                final effectiveMax = maxVal == 0 ? 1 : maxVal;
                final barFraction = total / effectiveMax;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (total > 0)
                          Text(
                            '$total',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 110 * barFraction + (total > 0 ? 8 : 4),
                            child: total == 0
                                ? Container(
                                    height: 4,
                                    color: const Color(0xFFF3F4F6),
                                  )
                                : Column(
                                    children: [
                                      if (skipped > 0)
                                        Flexible(
                                          flex: skipped,
                                          child: Container(
                                            color: const Color(0xFFEF4444),
                                          ),
                                        ),
                                      if (taken > 0)
                                        Flexible(
                                          flex: taken,
                                          child: Container(
                                            color: const Color(0xFF22C55E),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.key,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _adherenceColor(int pct) {
    if (pct >= 80) return const Color(0xFF059669);
    if (pct >= 50) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildMedicationsSection() {
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
          const Row(
            children: [
              Icon(Icons.medication_outlined,
                  size: 22, color: Color(0xFF4F8CFF)),
              SizedBox(width: 10),
              Text(
                'Medications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingMeds)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Color(0xFF4F8CFF),
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading medications...',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 14),
                  ),
                ],
              ),
            )
          else if (_medications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No medications on record.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            )
          else
            ..._medications.map(_buildMedTile),
        ],
      ),
    );
  }

  Widget _buildMedTile(Medication med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: med.isActive
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: med.isActive
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.medication_outlined,
              size: 22,
              color:
                  med.isActive ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  med.dosage,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (med.scheduleTimes.isNotEmpty)
                  Text(
                    med.scheduleTimes.join(' · '),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: med.isActive
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              med.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: med.isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
