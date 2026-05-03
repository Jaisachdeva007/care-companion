import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../services/firestore_service.dart';

class MedicationHistoryScreen extends StatelessWidget {
  final String medicationId;

  const MedicationHistoryScreen({super.key, required this.medicationId});

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      ),
      body: FutureBuilder(
        future: FirestoreService().getMedicationById(
          uid: uid,
          medicationId: medicationId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4F8CFF)),
                  SizedBox(height: 14),
                  Text('Loading history...',
                      style: TextStyle(color: Color(0xFF6B7280))),
                ],
              ),
            );
          }

          final medication = snapshot.data;
          if (medication == null || medication.logs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 64, color: Color(0xFF9CA3AF)),
                    SizedBox(height: 16),
                    Text(
                      'No history yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your taken and skipped logs will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          }

          final logs = medication.logs.reversed.toList();
          final takenCount =
              logs.where((l) => l.status == 'taken').length;
          final skippedCount =
              logs.where((l) => l.status == 'skipped').length;
          final total = logs.length;
          final adherencePct =
              total > 0 ? ((takenCount / total) * 100).round() : 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildSummaryCard(takenCount, skippedCount, adherencePct),
              const SizedBox(height: 8),
              Text(
                'Recent — newest first',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 10),
              ...logs.map((log) => _buildLogTile(log)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(int taken, int skipped, int adherencePct) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adherence Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statPill('$taken Taken', const Color(0xFFECFDF5),
                  const Color(0xFF065F46)),
              const SizedBox(width: 10),
              _statPill('$skipped Skipped', const Color(0xFFFEF2F2),
                  const Color(0xFFB91C1C)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _adherenceColor(adherencePct).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$adherencePct% adherence',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _adherenceColor(adherencePct),
                  ),
                ),
              ),
            ],
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

  Widget _statPill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildLogTile(MedicationLog log) {
    final isTaken = log.status == 'taken';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTaken
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isTaken
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isTaken ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: isTaken
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTaken ? 'Taken' : 'Skipped',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isTaken
                        ? const Color(0xFF065F46)
                        : const Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDateTime(log.scheduledTime),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
