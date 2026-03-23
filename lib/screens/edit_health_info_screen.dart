import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class EditHealthInfoScreen extends StatefulWidget {
  const EditHealthInfoScreen({super.key});

  @override
  State<EditHealthInfoScreen> createState() => _EditHealthInfoScreenState();
}

class _EditHealthInfoScreenState extends State<EditHealthInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  final preferredNameController = TextEditingController();
  final ageController = TextEditingController();
  final bloodGroupController = TextEditingController();
  final importantInfoController = TextEditingController();
  final conditionsController = TextEditingController();
  final allergiesController = TextEditingController();
  final medicationsController = TextEditingController();
  final mobilityNeedsController = TextEditingController();

  String inputPreference = 'manual';
  bool voiceAssistantEnabled = false;
  bool largeTextEnabled = false;
  bool isLoading = true;

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
        bloodGroupController.text = data['bloodGroup'] ?? '';
        importantInfoController.text = data['importantInfo'] ?? '';

        final healthConditions =
            List<String>.from(data['healthConditions'] ?? []);
        final allergies = List<String>.from(data['allergies'] ?? []);
        final medications = List<String>.from(data['medications'] ?? []);

        conditionsController.text = healthConditions.join(', ');
        allergiesController.text = allergies.join(', ');
        medicationsController.text = medications.join(', ');
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

    try {
      final user = FirebaseAuth.instance.currentUser!;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'preferredName': preferredNameController.text.trim(),
        'age': ageController.text.trim(),
        'bloodGroup': bloodGroupController.text.trim(),
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
        'medications': medicationsController.text
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

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update health info: $e')),
      );
    }
  }

  Widget buildField(
    TextEditingController controller,
    String label, {
    String? hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (value) {
          if ((label == 'Preferred Name' || label == 'Age') &&
              (value == null || value.trim().isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    preferredNameController.dispose();
    ageController.dispose();
    bloodGroupController.dispose();
    importantInfoController.dispose();
    conditionsController.dispose();
    allergiesController.dispose();
    medicationsController.dispose();
    mobilityNeedsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Health Info'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              buildField(preferredNameController, 'Preferred Name'),
              buildField(
                ageController,
                'Age',
                keyboardType: TextInputType.number,
              ),
              buildField(
                bloodGroupController,
                'Blood Group',
                hintText: 'e.g. O+, A-, B+, AB+',
              ),
              buildField(
                importantInfoController,
                'Important Info',
                hintText:
                    'e.g. asthma, diabetes, seizure history, heart condition',
                maxLines: 3,
              ),
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
                  onPressed: saveHealthInfo,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}