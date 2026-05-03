import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class ManualQuestionnaireScreen extends StatefulWidget {
  const ManualQuestionnaireScreen({super.key});

  @override
  State<ManualQuestionnaireScreen> createState() =>
      _ManualQuestionnaireScreenState();
}

class _ManualQuestionnaireScreenState
    extends State<ManualQuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();

  final preferredNameController = TextEditingController();
  final ageController = TextEditingController();
  final conditionsController = TextEditingController();
  final allergiesController = TextEditingController();
  final medicationsController = TextEditingController();
  final mobilityNeedsController = TextEditingController();

  String inputPreference = 'manual';
  bool voiceAssistantEnabled = false;
  bool largeTextEnabled = false;
  bool isLoading = false;

  Future<void> saveQuestionnaire() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;

      await FirestoreService().saveQuestionnaire(
        uid: user.uid,
        preferredName: preferredNameController.text.trim(),
        age: ageController.text.trim(),
        healthConditions: conditionsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        allergies: allergiesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        medications: medicationsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        mobilityNeeds: mobilityNeedsController.text.trim(),
        inputPreference: inputPreference,
        voiceAssistantEnabled: voiceAssistantEnabled,
        largeTextEnabled: largeTextEnabled,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving questionnaire: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
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
    String? hint,
    bool requiredField = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) {
          if (requiredField && (value == null || value.trim().isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
        decoration: _inputDecoration(label, hint: hint),
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
    conditionsController.dispose();
    allergiesController.dispose();
    medicationsController.dispose();
    mobilityNeedsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Manual Questionnaire',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(
                      Icons.assignment_rounded,
                      size: 68,
                      color: Color(0xFF4F8CFF),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tell us a little about your care needs',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fill in the form below so we can personalize your experience.',
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

                          buildSectionTitle('Health Information'),
                          buildField(
                            conditionsController,
                            'Health Conditions',
                            hint: 'Example: Diabetes, Arthritis',
                          ),
                          buildField(
                            allergiesController,
                            'Allergies',
                            hint: 'Example: Peanuts, Penicillin',
                          ),
                          buildField(
                            medicationsController,
                            'Medications',
                            hint: 'Example: Metformin, Vitamin D',
                          ),
                          buildField(
                            mobilityNeedsController,
                            'Mobility Needs',
                            hint: 'Example: Walker, Wheelchair, None',
                          ),

                          buildSectionTitle('Preferences'),
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

                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text(
                                'Enable Voice Assistant',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              subtitle: const Text(
                                'Use spoken guidance and voice help.',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 13),
                              ),
                              value: voiceAssistantEnabled,
                              activeColor: const Color(0xFF4F8CFF),
                              onChanged: (value) {
                                setState(() {
                                  voiceAssistantEnabled = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text(
                                'Enable Large Text',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              subtitle: const Text(
                                'Increase readability across the app.',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 13),
                              ),
                              value: largeTextEnabled,
                              activeColor: const Color(0xFF4F8CFF),
                              onChanged: (value) {
                                setState(() {
                                  largeTextEnabled = value;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : saveQuestionnaire,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F8CFF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: isLoading
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Saving...',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Save Questionnaire',
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
    );
  }
}