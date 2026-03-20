import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'auth_gate.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final languageController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();

  final emergencyNameController = TextEditingController();
  final emergencyPhoneController = TextEditingController();
  final emergencyRelationController = TextEditingController();

  String selectedRole = 'senior';
  bool isLoading = false;

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final emergencyContacts = [
        {
          'name': emergencyNameController.text.trim(),
          'phone': emergencyPhoneController.text.trim(),
          'relation': emergencyRelationController.text.trim(),
        }
      ];

      await FirestoreService().completeProfile(
        uid: currentUser.uid,
        fullName: fullNameController.text.trim(),
        role: selectedRole,
        language: languageController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        emergencyContacts: emergencyContacts,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
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
    fullNameController.dispose();
    languageController.dispose();
    phoneController.dispose();
    addressController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
    emergencyRelationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              buildField(fullNameController, 'Full Name'),

              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'senior',
                    child: Text('Senior'),
                  ),
                  DropdownMenuItem(
                    value: 'caregiver',
                    child: Text('Caregiver'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedRole = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              buildField(languageController, 'Language'),
              buildField(phoneController, 'Phone'),
              buildField(addressController, 'Address'),

              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Emergency Contact',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              buildField(emergencyNameController, 'Emergency Contact Name'),
              buildField(emergencyPhoneController, 'Emergency Contact Phone'),
              buildField(emergencyRelationController, 'Emergency Contact Relation'),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveProfile,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}