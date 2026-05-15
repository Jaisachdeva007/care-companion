import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/alert_item.dart';
import '../models/app_user.dart';
import '../models/caregiver_message.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'edit_health_info_screen.dart';
import 'edit_profile_screen.dart';
import 'emergency_services_screen.dart';
import 'login_screen.dart';
import 'medication_list_screen.dart';
import 'caregiver_access_screen.dart';
import 'link_senior_screen.dart';
import 'senior_detail_screen.dart';
import '../widgets/custom_bottom_nav_bar.dart';

  class HomeScreen extends StatefulWidget {
    final bool showBottomNav;

    const HomeScreen({
      super.key,
      this.showBottomNav = true,
    });

    @override
    State<HomeScreen> createState() => _HomeScreenState();
  }

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FlutterTts _tts = FlutterTts();
  bool _isSendingAlert = false;
  bool _canResendAlert = true;
  Timer? _alertCooldownTimer;
  // track message IDs already spoken so stream rebuilds don't re-speak
  final Set<String> _spokenMessageIds = {};

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
  }

  @override
  void dispose() {
    _alertCooldownTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

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

  List<String> _extractLinkedSeniorUids(Map<String, dynamic> userData) {
    final multi = List<String>.from(userData['linkedSeniorUids'] ?? []);
    final single = (userData['linkedSeniorUid'] ?? '').toString().trim();

    final result = <String>{...multi};
    if (single.isNotEmpty) {
      result.add(single);
    }

    return result.toList();
  }

  List<String> _extractLinkedCaregiverUids(Map<String, dynamic> userData) {
    final multi = List<String>.from(userData['linkedCaregiverUids'] ?? []);
    final single = (userData['linkedCaregiverUid'] ?? '').toString().trim();

    final result = <String>{...multi};
    if (single.isNotEmpty) {
      result.add(single);
    }

    return result.toList();
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

  String _formatAlertTime(DateTime? dt) {
    if (dt == null) return 'Just now';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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

  Future<void> _showCheckOnMeDialog(
    String seniorUid,
    List<String> caregiverNames,
  ) async {
    final nameDisplay = caregiverNames.isEmpty
        ? 'your caregiver'
        : caregiverNames.length == 1
            ? caregiverNames.first
            : caregiverNames.join(' and ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Send alert?'),
          content: Text(
            '$nameDisplay will be notified immediately to check on you.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send Alert'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isSendingAlert = true;
    });

    try {
      await _firestoreService.createCheckOnMeAlert(seniorUid: seniorUid);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alert sent to $nameDisplay.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      setState(() => _canResendAlert = false);
      _alertCooldownTimer?.cancel();
      _alertCooldownTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _canResendAlert = true);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send alert: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingAlert = false;
        });
      }
    }
  }

  Future<void> _resolveAlert(String alertId) async {
    try {
      await _firestoreService.resolveAlert(alertId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert marked as resolved.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve alert: $e')),
      );
    }
  }

  static const _presetMessages = [
    'Please take your medication 💊',
    'I hope you\'re feeling good today! 😊',
    'Just checking in on you ❤️',
    'Please call me when you can 📞',
    'Don\'t forget to drink water 💧',
  ];

  void _showSendMessageSheet(BuildContext context, String caregiverUid, AppUser senior) {
    final controller = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> send(String message) async {
            if (message.trim().isEmpty) return;
            setSheetState(() => isSending = true);
            try {
              await _firestoreService.sendCaregiverMessage(
                caregiverUid: caregiverUid,
                seniorUid: senior.uid,
                message: message.trim(),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Message sent to ${senior.fullName}.')),
                );
              }
            } catch (e) {
              setSheetState(() => isSending = false);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed to send: $e')),
                );
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Message ${senior.fullName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select a quick message or write your own.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetMessages.map((msg) => GestureDetector(
                      onTap: isSending ? null : () => send(msg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF4F8CFF)),
                        ),
                        child: Text(
                          msg,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F8CFF),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a custom message...',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        borderSide: const BorderSide(color: Color(0xFF4F8CFF)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSending ? null : () => send(controller.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F8CFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        isSending ? 'Sending...' : 'Send Message',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser!;
    final authService = AuthService();

    return StreamBuilder(
      stream: _firestoreService.getUserStream(firebaseUser.uid),
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

        final userData = Map<String, dynamic>.from(snapshot.data!.data()!);
        final fullName = (userData['fullName'] ?? '').toString();
        final role = (userData['role'] ?? 'senior').toString();
        final linkedCaregiverUids = _extractLinkedCaregiverUids(userData);

        return FutureBuilder<List<AppUser>>(
          future: role == 'senior' && linkedCaregiverUids.isNotEmpty
              ? _firestoreService.getUsersByUids(linkedCaregiverUids)
              : Future.value([]),
          builder: (context, caregiverSnapshot) {
            final caregivers = caregiverSnapshot.data ?? [];

            if (role == 'senior') {
              userData['linkedCaregiverNames'] = caregivers
                  .map((caregiver) => caregiver.fullName.trim())
                  .where((name) => name.isNotEmpty)
                  .toList();
            }

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
                backgroundColor: const Color(0xFFF5F7FB),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    UserAccountsDrawerHeader(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F7FB),
                      ),
                      accountName: Text(
                        fullName.isEmpty ? 'User' : fullName,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      accountEmail: Text(
                        firebaseUser.email ?? '',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      currentAccountPicture: const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 32,
                          color: Color(0xFF4F8CFF),
                        ),
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
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Profile'),
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
                    if (role == 'senior') ...[
                      ListTile(
                        leading: const Icon(Icons.health_and_safety),
                        title: const Text('Health Info'),
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
                      ListTile(
                        leading: const Icon(Icons.link_outlined),
                        title: const Text('Caregiver Access'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CaregiverAccessScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                    if (role == 'caregiver')
                      ListTile(
                        leading: const Icon(Icons.person_add_alt_1_outlined),
                        title: const Text('Link a Senior'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LinkSeniorScreen(),
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
                      if (role == 'senior') ...[
                        _buildCaregiverMessageSection(firebaseUser.uid),
                        const SizedBox(height: 18),
                        _buildCheckOnMeCard(
                          uid: firebaseUser.uid,
                          userData: userData,
                        ),
                        const SizedBox(height: 18),
                        _buildMedicationSummaryCard(context, firebaseUser.uid),
                        const SizedBox(height: 22),
                      ] else ...[
                          _buildLinkedSeniorsList(_extractLinkedSeniorUids(userData), firebaseUser.uid),
                          const SizedBox(height: 18),
                          _buildCaregiverAlertsSection(firebaseUser.uid),
                          const SizedBox(height: 22),
                        ],
                      _buildEmergencyCard(context),
                    ],
                  ),
                ),
              ),
                bottomNavigationBar: const CustomBottomNavBar(
                currentTab: AppTab.home,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIdentityCard({
    required BuildContext context,
    required String fullName,
    required String role,
    required Map<String, dynamic> userData,
  }) {
    final displayName = fullName.isEmpty ? 'User' : fullName;

    if (role == 'caregiver') {
      final linkedSeniorUids = _extractLinkedSeniorUids(userData);

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
                    Icons.people_alt_outlined,
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
                            icon: Icons.link_outlined,
                            label:
                                '${linkedSeniorUids.length} linked senior${linkedSeniorUids.length == 1 ? '' : 's'}',
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
                        builder: (_) => const EditProfileScreen(),
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
          ],
        ),
      );
    }

    final bloodGroup = (userData['bloodGroup'] ?? 'Not added').toString();

    String emergencyContact = 'Not added';
    String emergencyPhone = '';
    final contacts = userData['emergencyContacts'];

    if (contacts is List && contacts.isNotEmpty) {
      final first = contacts.first;
      final name = (first['name'] ?? '').toString();
      final phone = (first['phone'] ?? '').toString();
      emergencyPhone = phone;

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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EditHealthInfoScreen()),
                ),
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSoftInfoTile(
            icon: Icons.call_outlined,
            title: 'Emergency Contact',
            value: emergencyContact,
            onTap: emergencyPhone.isNotEmpty
                ? () => launchUrl(Uri(scheme: 'tel', path: emergencyPhone))
                : null,
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
          Icon(icon, size: 18, color: const Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
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
    VoidCallback? onTap,
  }) {
    final tile = Container(
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not added' : value,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.phone_forwarded_outlined,
              size: 18,
              color: Color(0xFF4F8CFF),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: tile);
    }
    return tile;
  }

  Widget _buildCardInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? 'Not added' : value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.call_made_rounded,
              size: 16, color: Colors.white.withValues(alpha: 0.7)),
      ],
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: row);
    }
    return row;
  }

  Widget _buildCheckOnMeCard({
    required String uid,
    required Map<String, dynamic> userData,
  }) {
    final linkedCaregiverUids = _extractLinkedCaregiverUids(userData);
    final hasCaregiver = linkedCaregiverUids.isNotEmpty;
    final caregiverNames =
        List<String>.from(userData['linkedCaregiverNames'] ?? []);

    final nameDisplay = caregiverNames.isEmpty
        ? 'your caregiver'
        : caregiverNames.length == 1
            ? caregiverNames.first
            : caregiverNames.join(' & ');

    return StreamBuilder<AlertItem?>(
      stream: _firestoreService.getActiveAlertForSenior(uid),
      builder: (context, snapshot) {
        final activeAlert = snapshot.data;
        final hasActiveAlert = activeAlert != null;

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
                    Icons.notifications_active_outlined,
                    size: 26,
                    color: Color(0xFFB91C1C),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Check on Me',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!hasCaregiver)
                const Text(
                  'Link a caregiver first to use this feature.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Color(0xFF6B7280),
                  ),
                )
              else ...[
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Color(0xFF6B7280),
                    ),
                    children: [
                      const TextSpan(
                          text: 'Your caregiver: '),
                      TextSpan(
                        text: nameDisplay,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const TextSpan(
                          text: '. Press the button below if you need someone to check on you.'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (hasActiveAlert && !_canResendAlert) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF16A34A),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Alert sent — your caregiver has been notified.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              if (activeAlert.createdAt != null)
                                Text(
                                  'Sent ${_formatAlertTime(activeAlert.createdAt)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!hasCaregiver || _isSendingAlert || (hasActiveAlert && !_canResendAlert))
                      ? null
                      : () => _showCheckOnMeDialog(uid, caregiverNames),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    disabledBackgroundColor: (hasActiveAlert && !_canResendAlert)
                        ? const Color(0xFF16A34A)
                        : null,
                    disabledForegroundColor: (hasActiveAlert && !_canResendAlert)
                        ? Colors.white
                        : null,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSendingAlert
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon((hasActiveAlert && !_canResendAlert)
                          ? Icons.check_rounded
                          : Icons.campaign_outlined),
                  label: Text(
                    _isSendingAlert
                        ? 'Sending...'
                        : (hasActiveAlert && !_canResendAlert)
                            ? 'Alert Sent'
                            : 'Alert $nameDisplay',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildCaregiverAlertsSection(String caregiverUid) {
    return StreamBuilder<List<AlertItem>>(
      stream: _firestoreService.getActiveAlertsForCaregiver(caregiverUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
                Text('Loading alerts...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              'Could not load alerts: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFFDC2626)),
            ),
          );
        }

        final alerts = snapshot.data ?? [];

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
                    Icons.notification_important_outlined,
                    size: 26,
                    color: Color(0xFFB91C1C),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Active Alerts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (alerts.isEmpty)
                const Text(
                  'No active alerts right now.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
                )
              else
                ...alerts.map((alert) => _buildAlertTile(alert)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertTile(AlertItem alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert.seniorName.isEmpty ? 'Senior User' : alert.seniorName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            alert.message,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatAlertTime(alert.createdAt),
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => _resolveAlert(alert.id),
              child: const Text('Mark Resolved'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverMessageSection(String seniorUid) {
    return StreamBuilder<List<CaregiverMessage>>(
      stream: _firestoreService.getUnreadCaregiverMessages(seniorUid),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];

        if (messages.isEmpty) return const SizedBox.shrink();

        // speak any new messages
        for (final msg in messages) {
          if (!_spokenMessageIds.contains(msg.id)) {
            _spokenMessageIds.add(msg.id);
            Future.delayed(const Duration(milliseconds: 300), () {
              _tts.speak('Message from ${msg.caregiverName}: ${msg.message}');
            });
          }
        }

        return Column(
          children: messages.map((msg) => _buildMessageCard(msg)).toList(),
        );
      },
    );
  }

  Widget _buildMessageCard(CaregiverMessage msg) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF86EFAC)),
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
          Row(
            children: [
              const Icon(Icons.message_rounded, size: 22, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Message from ${msg.caregiverName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _tts.speak('Message from ${msg.caregiverName}: ${msg.message}');
                },
                child: const Icon(Icons.volume_up_rounded, size: 20, color: Color(0xFF16A34A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            msg.message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () async {
                await _firestoreService.markCaregiverMessageRead(msg.id);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Got it ✓',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedSeniorsList(List<String> linkedSeniorUids, String caregiverUid) {
    return FutureBuilder<List<AppUser>>(
      future: _firestoreService.getUsersByUids(linkedSeniorUids),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
                Text('Loading linked seniors...'),
              ],
            ),
          );
        }

        final seniors = snapshot.data ?? [];

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
              Row(
                children: [
                  const Icon(
                    Icons.person_search_outlined,
                    size: 26,
                    color: Color(0xFF111827),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Linked Seniors (${seniors.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (seniors.isEmpty)
                const Text(
                  'No seniors linked yet.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
                )
              else
                ...seniors.map((senior) => _buildSeniorListTile(senior, caregiverUid)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeniorListTile(AppUser senior, String caregiverUid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SeniorDetailScreen(senior: senior),
              ),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFEFF4FF),
              backgroundImage: senior.photoBase64.isNotEmpty
                  ? MemoryImage(base64Decode(senior.photoBase64))
                  : null,
              child: senior.photoBase64.isEmpty
                  ? const Icon(Icons.person_rounded, size: 24, color: Color(0xFF4F8CFF))
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SeniorDetailScreen(senior: senior),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senior.fullName.isEmpty ? 'Unnamed Senior' : senior.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    senior.phone.isEmpty ? 'No phone' : senior.phone,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showSendMessageSheet(context, caregiverUid, senior),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4F8CFF).withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.message_outlined, size: 18, color: Color(0xFF4F8CFF)),
                  SizedBox(width: 6),
                  Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F8CFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationSummaryCard(BuildContext context, String uid) {
  return StreamBuilder(
    stream: _firestoreService.getMedicationsStream(uid),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildMedicationLoadingCard();
      }

      final medications = snapshot.data ?? [];
      final activeMeds =
          medications.where((med) => med.isActive == true).toList();
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
                  'Next Medication',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (nextMedication == null)
              const Text(
                'No upcoming medication right now.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nextMedication['name'] as String,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'at ${_formatDisplayTime(nextMedication['time'] as DateTime)}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDueIn(nextMedication['time'] as DateTime),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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

  Widget _buildEmergencyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFE4E6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 22,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Emergency Support',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
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
                  backgroundColor: const Color(0xFFDC2626),
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