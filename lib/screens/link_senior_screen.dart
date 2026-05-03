import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class LinkSeniorScreen extends StatefulWidget {
  const LinkSeniorScreen({super.key});

  @override
  State<LinkSeniorScreen> createState() => _LinkSeniorScreenState();
}

class _LinkSeniorScreenState extends State<LinkSeniorScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _caregiverCodeController = TextEditingController();

  bool _isLinking = false;

  @override
  void dispose() {
    _caregiverCodeController.dispose();
    super.dispose();
  }

  List<String> _extractLinkedSeniorUids(Map<String, dynamic> userData) {
    final multi = List<String>.from(userData['linkedSeniorUids'] ?? []);
    final single = (userData['linkedSeniorUid'] ?? '').toString().trim();

    final result = <String>{...multi};
    if (single.isNotEmpty) result.add(single);

    return result.toList();
  }

  Future<void> _linkSenior(String caregiverUid) async {
    if (_caregiverCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a caregiver code')),
      );
      return;
    }

    setState(() => _isLinking = true);

    try {
      final result = await _firestoreService.linkCaregiverToSenior(
        caregiverUid: caregiverUid,
        code: _caregiverCodeController.text.trim(),
      );

      if (!mounted) return;

      final isSuccess = result.toLowerCase().contains('success') ||
          result.toLowerCase().contains('linked');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: isSuccess
              ? const Color(0xFF059669)
              : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      if (isSuccess) _caregiverCodeController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Widget _buildSeniorCard(AppUser senior) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senior.fullName.isEmpty ? 'Unnamed Senior' : senior.fullName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          _info('Phone', senior.phone),
          _info('Address', senior.address),
          _info('Blood Group', senior.bloodGroup),
          _info(
            'Allergies',
            senior.allergies.isEmpty ? '' : senior.allergies.join(', '),
          ),
          _info(
            'Conditions',
            senior.healthConditions.isEmpty
                ? ''
                : senior.healthConditions.join(', '),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedSection(List<String> uids) {
    return FutureBuilder<List<AppUser>>(
      future: _firestoreService.getUsersByUids(uids),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4F8CFF),
              ),
            ),
          );
        }

        final seniors = snapshot.data!;

        return Container(
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
                'Linked Seniors (${seniors.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (seniors.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Icon(Icons.person_search_outlined,
                          size: 40, color: Color(0xFF9CA3AF)),
                      SizedBox(height: 10),
                      Text(
                        'No seniors linked yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Enter the code from a senior\'s app above.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                )
              else
                ...seniors.map(_buildSeniorCard),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Link a Senior',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      ),
      body: StreamBuilder(
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
                currentTab: AppTab.seniors,
              ),
            );
          }

          final userData = snapshot.data!.data()!;
          final linkedUids = _extractLinkedSeniorUids(userData);

          return SingleChildScrollView(
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
                        Icons.people_alt_rounded,
                        size: 60,
                        color: Color(0xFF4F8CFF),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Connect to a Senior',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Enter the code shared by a senior to connect accounts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _caregiverCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'ABC123',
                          hintStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 3,
                            color: Color(0xFFD1D5DB),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Color(0xFF4F8CFF), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isLinking ? null : () => _linkSenior(uid),
                          icon: _isLinking
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.link_rounded, size: 18),
                          label: Text(
                            _isLinking ? 'Linking...' : 'Link Senior',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
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
                _buildLinkedSection(linkedUids),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const CustomBottomNavBar(
        currentTab: AppTab.seniors,
      ),
    );
  }
}