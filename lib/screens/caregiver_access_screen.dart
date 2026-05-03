import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class CaregiverAccessScreen extends StatefulWidget {
  const CaregiverAccessScreen({super.key});

  @override
  State<CaregiverAccessScreen> createState() => _CaregiverAccessScreenState();
}

class _CaregiverAccessScreenState extends State<CaregiverAccessScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isGeneratingCode = false;

  List<String> _extractLinkedCaregiverUids(Map<String, dynamic> userData) {
    final multi = List<String>.from(userData['linkedCaregiverUids'] ?? []);
    final single = (userData['linkedCaregiverUid'] ?? '').toString().trim();

    final result = <String>{...multi};
    if (single.isNotEmpty) result.add(single);

    return result.toList();
  }

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Code copied to clipboard'),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _generateCaregiverCode(String uid) async {
    setState(() => _isGeneratingCode = true);

    try {
      final code = await _firestoreService.generateCaregiverCode(uid);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Caregiver code generated: $code')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingCode = false);
    }
  }

  Widget _buildCaregiverTile(AppUser caregiver) {
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
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person, color: Color(0xFF4F8CFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caregiver.fullName.isEmpty
                      ? 'Unnamed Caregiver'
                      : caregiver.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caregiver.email.isEmpty ? 'No email' : caregiver.email,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder(
      stream: _firestoreService.getUserStream(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4F8CFF),
              ),
            ),
            bottomNavigationBar: CustomBottomNavBar(
              currentTab: AppTab.profile,
            ),
          );
        }

        final userData = snapshot.data!.data()!;
        final caregiverCode = (userData['caregiverCode'] ?? '').toString();
        final linkedCaregiverUids = _extractLinkedCaregiverUids(userData);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          appBar: AppBar(
            title: const Text(
              'Caregiver Access',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: const Color(0xFFF5F7FB),
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
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
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        size: 50,
                        color: Color(0xFF4F8CFF),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your Caregiver Code',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Share this code with your caregiver so they can link to your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (caregiverCode.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD6E6FF)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                caregiverCode,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 6,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                              const SizedBox(width: 14),
                              GestureDetector(
                                onTap: () => _copyCode(context, caregiverCode),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFD6E6FF)),
                                  ),
                                  child: const Icon(Icons.copy_rounded,
                                      size: 18, color: Color(0xFF4F8CFF)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Text(
                            '— — — — — —',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        '${linkedCaregiverUids.length} caregiver${linkedCaregiverUids.length == 1 ? '' : 's'} linked',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isGeneratingCode
                              ? null
                              : () => _generateCaregiverCode(uid),
                          icon: _isGeneratingCode
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  caregiverCode.isEmpty
                                      ? Icons.key_outlined
                                      : Icons.refresh,
                                  size: 18,
                                ),
                          label: Text(
                            _isGeneratingCode
                                ? 'Generating...'
                                : caregiverCode.isEmpty
                                    ? 'Generate Code'
                                    : 'Regenerate Code',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F8CFF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Linked Caregivers (${linkedCaregiverUids.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (linkedCaregiverUids.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            children: [
                              Icon(Icons.person_add_outlined,
                                  size: 40, color: Color(0xFF9CA3AF)),
                              SizedBox(height: 10),
                              Text(
                                'No caregivers linked yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Generate a code above and share it with your caregiver.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        FutureBuilder<List<AppUser>>(
                          future: _firestoreService
                              .getUsersByUids(linkedCaregiverUids),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4F8CFF),
                                ),
                              );
                            }

                            return Column(
                              children:
                                  snapshot.data!.map(_buildCaregiverTile).toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const CustomBottomNavBar(
            currentTab: AppTab.profile,
          ),
        );
      },
    );
  }
}