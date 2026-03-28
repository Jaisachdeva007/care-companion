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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result)));

      if (result.toLowerCase().contains('success')) {
        _caregiverCodeController.clear();
      }
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
          _info('Allergies', senior.allergies.join(', ')),
          _info('Conditions', senior.healthConditions.join(', ')),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$label: ${value.isEmpty ? "Not added" : value}',
        style: const TextStyle(color: Color(0xFF374151)),
      ),
    );
  }

  Widget _buildLinkedSection(List<String> uids) {
    return FutureBuilder<List<AppUser>>(
      future: _firestoreService.getUsersByUids(uids),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
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
                const Text('No seniors linked yet.')
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
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data()!;
          final linkedUids = _extractLinkedSeniorUids(userData);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 🔹 LINK CARD
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
                        decoration: InputDecoration(
                          hintText: 'Enter caregiver code',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLinking
                              ? null
                              : () => _linkSenior(uid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F8CFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLinking
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('Link Senior'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 LINKED LIST
                _buildLinkedSection(linkedUids),
              ],
            ),
          );
        },
      ),
    );
  }
}