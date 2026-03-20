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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving questionnaire: $e')),
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: (value) {
          if (label == 'Preferred Name' || label == 'Age') {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter $label';
            }
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
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
      appBar: AppBar(
        title: const Text('Manual Questionnaire'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              buildField(preferredNameController, 'Preferred Name'),
              buildField(ageController, 'Age'),
              buildField(
                conditionsController,
                'Health Conditions (comma separated)',
              ),
              buildField(
                allergiesController,
                'Allergies (comma separated)',
              ),
              buildField(
                medicationsController,
                'Medications (comma separated)',
              ),
              buildField(mobilityNeedsController, 'Mobility Needs'),

              DropdownButtonFormField<String>(
                initialValue: inputPreference,
                decoration: const InputDecoration(
                  labelText: 'Preferred Input Method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'manual', child: Text('Manual')),
                  DropdownMenuItem(value: 'voice', child: Text('Voice')),
                  DropdownMenuItem(value: 'guided', child: Text('Guided')),
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
                title: const Text('Enable Voice Assistant'),
                value: voiceAssistantEnabled,
                onChanged: (value) {
                  setState(() {
                    voiceAssistantEnabled = value;
                  });
                },
              ),

              SwitchListTile(
                title: const Text('Enable Large Text'),
                value: largeTextEnabled,
                onChanged: (value) {
                  setState(() {
                    largeTextEnabled = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveQuestionnaire,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Questionnaire'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}