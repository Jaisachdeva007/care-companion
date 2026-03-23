import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'edit_health_info_screen.dart';
import 'edit_profile_screen.dart';
import 'emergency_services_screen.dart';
import 'login_screen.dart';
import 'medication_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatRole(String role) {
    if (role.isEmpty) return 'User';
    return role[0].toUpperCase() + role.substring(1);
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
      return 'Due in $hours hr ${mins} min';
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final authService = AuthService();

    return StreamBuilder(
      stream: FirestoreService().getUserStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const Scaffold(
            body: Center(child: Text('No user data found')),
          );
        }

        final userData = snapshot.data!.data()!;
        final fullName = (userData['fullName'] ?? '').toString();
        final role = (userData['role'] ?? 'senior').toString();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF5F7FB),
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text(
              'Care Companion',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(fullName.isEmpty ? 'User' : fullName),
                  accountEmail: Text(user.email ?? ''),
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 32),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Home'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.emergency),
                  title: const Text('Emergency Services'),
                  subtitle: const Text(
                    'Find nearby hospital, ER, clinic, and pharmacy',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmergencyServicesScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Update My Info'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.health_and_safety),
                  title: const Text('Update Health Info'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditHealthInfoScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.medication),
                  title: const Text('Medications'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MedicationListScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log Out'),
                  onTap: () async {
                    Navigator.pop(context);
                    await authService.logout();

                    if (!context.mounted) return;

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIdentityCard(
                    context: context,
                    fullName: fullName,
                    role: role,
                    userData: userData,
                  ),
                  const SizedBox(height: 18),
                  _buildMedicationSummaryCard(context, user.uid),
                  const SizedBox(height: 22),
                  _buildSectionTitle('Quick Actions'),
                  const SizedBox(height: 14),
                  _buildQuickActionsSection(context),
                  const SizedBox(height: 22),
                  _buildEmergencyCard(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildIdentityCard({
    required BuildContext context,
    required String fullName,
    required String role,
    required Map<String, dynamic> userData,
  }) {
    final displayName = fullName.isEmpty ? 'User' : fullName;
    final bloodGroup = (userData['bloodGroup'] ?? 'Not added').toString();

    String emergencyContact = 'Not added';
    final contacts = userData['emergencyContacts'];

    if (contacts is List && contacts.isNotEmpty) {
      final first = contacts.first;
      final name = (first['name'] ?? '').toString();
      final phone = (first['phone'] ?? '').toString();

      if (name.isNotEmpty || phone.isNotEmpty) {
        emergencyContact = phone.isEmpty ? name : '$name  •  $phone';
      }
    }

    final allergiesList = userData['allergies'];
    final allergies = allergiesList is List && allergiesList.isNotEmpty
        ? allergiesList.join(', ')
        : 'Not added';

    final conditionsList = userData['healthConditions'];
    final conditions = conditionsList is List && conditionsList.isNotEmpty
        ? conditionsList.join(', ')
        : 'Not added';

    final importantInfo = (userData['importantInfo'] ?? '').toString().trim();
    final importantDisplay = importantInfo.isEmpty ? conditions : importantInfo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getGreeting()}, $displayName',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 30,
                  color: Color(0xFF4F8CFF),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(
                          icon: Icons.badge_outlined,
                          label: _formatRole(role),
                        ),
                        _buildChip(
                          icon: Icons.bloodtype_outlined,
                          label: bloodGroup.isEmpty ? 'Not added' : bloodGroup,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditHealthInfoScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSoftInfoTile(
            icon: Icons.call_outlined,
            title: 'Emergency Contact',
            value: emergencyContact,
          ),
          const SizedBox(height: 10),
          _buildSoftInfoTile(
            icon: Icons.warning_amber_rounded,
            title: 'Allergies',
            value: allergies,
          ),
          const SizedBox(height: 10),
          _buildSoftInfoTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Important Info',
            value: importantDisplay,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F2F5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF4F8CFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not added' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationSummaryCard(BuildContext context, String uid) {
    return StreamBuilder(
      stream: FirestoreService().getMedicationsStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildMedicationLoadingCard();
        }

        final medications = snapshot.data ?? [];
        final activeMeds =
            medications.where((med) => med.isActive == true).toList();
        final totalActive = activeMeds.length;
        final nextMedication = _getNextMedication(activeMeds);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 28,
                    color: Color(0xFF111827),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Today’s Medications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (totalActive == 0) ...[
                const Text(
                  'No active medications right now.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (nextMedication != null) ...[
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
                      Text(
                        nextMedication['name'] as String,
                        style: const TextStyle(
                          fontSize: 18,
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
                          _buildMiniPill(
                            label:
                                'Next at ${_formatDisplayTime(nextMedication['time'] as DateTime)}',
                          ),
                          _buildMiniPill(
                            label: _formatDueIn(
                              nextMedication['time'] as DateTime,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildStatBox(
                    label: 'Active',
                    value: '$totalActive',
                  ),
                  _buildStatBox(
                    label: 'Scheduled Today',
                    value: activeMeds.isEmpty
                        ? '0'
                        : '${activeMeds.fold<int>(0, (sum, med) => sum + med.scheduleTimes.length)}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEF2FF),
                    foregroundColor: const Color(0xFF374151),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MedicationListScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Open Medications',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMedicationLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading medication summary...'),
        ],
      ),
    );
  }

  Widget _buildMiniPill({required String label}) {
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

  Widget _buildStatBox({
    required String label,
    required String value,
  }) {
    return Container(
      width: 120,
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

  Widget _buildQuickActionsSection(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.08,
      children: [
        _buildActionCard(
          title: 'Medications',
          subtitle: 'View and manage meds',
          icon: Icons.medication_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MedicationListScreen(),
              ),
            );
          },
        ),
        _buildActionCard(
          title: 'Emergency',
          subtitle: 'Nearby help and support',
          icon: Icons.emergency_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EmergencyServicesScreen(),
              ),
            );
          },
        ),
        _buildActionCard(
          title: 'Profile',
          subtitle: 'Edit your personal info',
          icon: Icons.person_outline,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EditProfileScreen(),
              ),
            );
          },
        ),
        _buildActionCard(
          title: 'Health Info',
          subtitle: 'Update medical details',
          icon: Icons.health_and_safety_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EditHealthInfoScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF4F8CFF),
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFE7C2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 30,
                  color: Color(0xFFF59E0B),
                ),
                SizedBox(width: 10),
                Text(
                  'Emergency Support',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Quickly access nearby hospitals, emergency rooms, walk-in clinics, and pharmacies.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmergencyServicesScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.location_on_outlined),
                label: const Text(
                  'Open Emergency Services',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}