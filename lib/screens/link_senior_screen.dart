import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';

class LinkSeniorScreen extends StatefulWidget {
  const LinkSeniorScreen({super.key});

  @override
  State<LinkSeniorScreen> createState() => _LinkSeniorScreenState();
}

class _LinkSeniorScreenState extends State<LinkSeniorScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _caregiverCodeController = TextEditingController();

  bool _isLinkingCaregiver = false;

  @override
  void dispose() {
    _caregiverCodeController.dispose();
    super.dispose();
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

  Widget _buildInlineInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildSeniorListTile(AppUser senior) {
    String emergencyContact = 'Not added';
    if (senior.emergencyContacts.isNotEmpty) {
      final first = senior.emergencyContacts.first;
      final name = (first['name'] ?? '').toString();
      final phone = (first['phone'] ?? '').toString();

      if (name.isNotEmpty || phone.isNotEmpty) {
        emergencyContact = phone.isEmpty ? name : '$name  •  $phone';
      }
    }

    final bloodGroup =
        senior.bloodGroup.isEmpty ? 'Not added' : senior.bloodGroup;

    final allergies =
        senior.allergies.isEmpty ? 'Not added' : senior.allergies.join(', ');

    final conditions = senior.healthConditions.isEmpty
        ? 'Not added'
        : senior.healthConditions.join(', ');

    final importantInfo = senior.importantInfo.trim().isEmpty
        ? conditions
        : senior.importantInfo;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
          _buildInlineInfo(
            'Phone',
            senior.phone.isEmpty ? 'Not added' : senior.phone,
          ),
          _buildInlineInfo(
            'Address',
            senior.address.isEmpty ? 'Not added' : senior.address,
          ),
          _buildInlineInfo('Blood Group', bloodGroup),
          _buildInlineInfo('Allergies', allergies),
          _buildInlineInfo('Health Conditions', conditions),
          _buildInlineInfo('Important Info', importantInfo),
          _buildInlineInfo('Emergency Contact', emergencyContact),
        ],
      ),
    );
  }

  Widget _buildLinkedSeniorsSection(List<String> linkedSeniorUids) {
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
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
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
                ...seniors.map((senior) => _buildSeniorListTile(senior)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _linkCaregiver(String caregiverUid) async {
    setState(() {
      _isLinkingCaregiver = true;
    });

    try {
      final result = await _firestoreService.linkCaregiverToSenior(
        caregiverUid: caregiverUid,
        code: _caregiverCodeController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );

      if (result.toLowerCase().contains('linked successfully')) {
        _caregiverCodeController.clear();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to link senior: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLinkingCaregiver = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final caregiverUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Link a Senior',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ),
      body: StreamBuilder(
        stream: _firestoreService.getUserStream(caregiverUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() ?? <String, dynamic>{};
          final linkedSeniorUids = _extractLinkedSeniorUids(userData);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                Container(
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
                            Icons.people_alt_outlined,
                            size: 26,
                            color: Color(0xFF111827),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Link a Senior',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Enter the caregiver code shared by a senior to connect them to your caregiver account.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _caregiverCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Caregiver Code',
                          hintText: 'Enter code',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF4F8CFF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLinkingCaregiver
                              ? null
                              : () => _linkCaregiver(caregiverUid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F8CFF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLinkingCaregiver
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Link Senior',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildLinkedSeniorsSection(linkedSeniorUids),
              ],
            ),
          );
        },
      ),
    );
  }
}