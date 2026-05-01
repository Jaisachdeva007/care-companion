import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'home_screen.dart';

class EditHealthInfoScreen extends StatefulWidget {
  const EditHealthInfoScreen({super.key});

  @override
  State<EditHealthInfoScreen> createState() => _EditHealthInfoScreenState();
}

class _EditHealthInfoScreenState extends State<EditHealthInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  final preferredNameController = TextEditingController();
  final ageController = TextEditingController();
  final importantInfoController = TextEditingController();
  final conditionsController = TextEditingController();
  final allergiesController = TextEditingController();
  final mobilityNeedsController = TextEditingController();

  String? _selectedBloodGroup;
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  String inputPreference = 'manual';
  bool voiceAssistantEnabled = false;
  bool largeTextEnabled = false;
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadHealthInfo();
  }

  Future<void> loadHealthInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final appUser = await FirestoreService().getUserByUid(user.uid);

      if (appUser != null) {
        final data = appUser.toMap();

        preferredNameController.text = data['preferredName'] ?? '';
        ageController.text = data['age'] ?? '';
        importantInfoController.text = data['importantInfo'] ?? '';

        final savedBloodGroup = (data['bloodGroup'] ?? '').toString();
        _selectedBloodGroup = _bloodGroups.contains(savedBloodGroup) ? savedBloodGroup : null;

        final healthConditions =
            List<String>.from(data['healthConditions'] ?? []);
        final allergies = List<String>.from(data['allergies'] ?? []);

        conditionsController.text = healthConditions.join(', ');
        allergiesController.text = allergies.join(', ');
        mobilityNeedsController.text = data['mobilityNeeds'] ?? '';

        inputPreference = data['inputPreference'] ?? 'manual';
        voiceAssistantEnabled = data['voiceAssistantEnabled'] ?? false;
        largeTextEnabled = data['largeTextEnabled'] ?? false;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load health info: $e')),
      );
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveHealthInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'preferredName': preferredNameController.text.trim(),
        'age': ageController.text.trim(),
        'bloodGroup': _selectedBloodGroup ?? '',
        'importantInfo': importantInfoController.text.trim(),
        'healthConditions': conditionsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'allergies': allergiesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'mobilityNeeds': mobilityNeedsController.text.trim(),
        'inputPreference': inputPreference,
        'voiceAssistantEnabled': voiceAssistantEnabled,
        'largeTextEnabled': largeTextEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health info updated successfully')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update health info: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
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
          width: 1.5,
        ),
      ),
    );
  }

  Widget buildField(
    TextEditingController controller,
    String label, {
    String? hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool requiredField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (value) {
          if (requiredField && (value == null || value.trim().isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
        decoration: _inputDecoration(label, hintText: hintText),
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    preferredNameController.dispose();
    ageController.dispose();
    importantInfoController.dispose();
    conditionsController.dispose();
    allergiesController.dispose();
    mobilityNeedsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4F8CFF),
          ),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentTab: AppTab.health,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Update Health Info',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF1F2937),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(
                      Icons.health_and_safety_rounded,
                      size: 70,
                      color: Color(0xFF4F8CFF),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Update your health details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Keep your medical and accessibility information up to date for better support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
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
                        children: [
                          buildSectionTitle('Basic Information'),
                          buildField(
                            preferredNameController,
                            'Preferred Name',
                            requiredField: true,
                          ),
                          buildField(
                            ageController,
                            'Age',
                            requiredField: true,
                            keyboardType: TextInputType.number,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: DropdownButtonFormField<String>(
                              value: _selectedBloodGroup,
                              decoration: _inputDecoration('Blood Group'),
                              hint: const Text('Select blood group'),
                              items: _bloodGroups
                                  .map((bg) => DropdownMenuItem(
                                        value: bg,
                                        child: Text(bg),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedBloodGroup = value;
                                });
                              },
                            ),
                          ),
                          buildSectionTitle('Important Medical Details'),
                          buildField(
                            importantInfoController,
                            'Important Info',
                            hintText:
                                'e.g. asthma, diabetes, seizure history, heart condition',
                            maxLines: 3,
                          ),
                          buildField(
                            conditionsController,
                            'Health Conditions',
                            hintText: 'Comma separated',
                          ),
                          buildField(
                            allergiesController,
                            'Allergies',
                            hintText: 'Comma separated',
                          ),
                          buildField(
                            mobilityNeedsController,
                            'Mobility Needs',
                            hintText: 'e.g. Walker, Wheelchair, Cane',
                          ),
                          buildSectionTitle('App Preferences'),
                          DropdownButtonFormField<String>(
                            initialValue: inputPreference,
                            decoration: _inputDecoration(
                              'Preferred Input Method',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'manual',
                                child: Text('Manual'),
                              ),
                              DropdownMenuItem(
                                value: 'voice',
                                child: Text('Voice'),
                              ),
                              DropdownMenuItem(
                                value: 'guided',
                                child: Text('Guided'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  inputPreference = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            tileColor: const Color(0xFFF9FAFB),
                            title: const Text(
                              'Enable Voice Assistant',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            subtitle: const Text(
                              'Use voice guidance and spoken assistance.',
                            ),
                            value: voiceAssistantEnabled,
                            activeColor: const Color(0xFF4F8CFF),
                            onChanged: (value) {
                              setState(() {
                                voiceAssistantEnabled = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            tileColor: const Color(0xFFF9FAFB),
                            title: const Text(
                              'Enable Large Text',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            subtitle: const Text(
                              'Increase text size for easier reading.',
                            ),
                            value: largeTextEnabled,
                            activeColor: const Color(0xFF4F8CFF),
                            onChanged: (value) {
                              setState(() {
                                largeTextEnabled = value;
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : saveHealthInfo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F8CFF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(
        currentTab: AppTab.health,
      ),
    );
  }
}