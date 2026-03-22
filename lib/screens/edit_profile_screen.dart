import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final languageController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();

  final emergencyNameController = TextEditingController();
  final emergencyPhoneController = TextEditingController();
  final emergencyRelationController = TextEditingController();

  bool isLoading = true;
  String selectedRole = 'senior';

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final appUser = await FirestoreService().getUserByUid(user.uid);

      if (appUser != null) {
        fullNameController.text = appUser.fullName;
        languageController.text = appUser.language;
        phoneController.text = appUser.phone;
        addressController.text = appUser.address;
        selectedRole = appUser.role;

        if (appUser.emergencyContacts.isNotEmpty) {
          final contact = appUser.emergencyContacts.first;
          emergencyNameController.text = contact['name'] ?? '';
          emergencyPhoneController.text = contact['phone'] ?? '';
          emergencyRelationController.text = contact['relation'] ?? '';
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load profile: $e')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = FirebaseAuth.instance.currentUser!;

      await FirestoreService().completeProfile(
        uid: user.uid,
        fullName: fullNameController.text.trim(),
        role: selectedRole,
        language: languageController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        emergencyContacts: [
          {
            'name': emergencyNameController.text.trim(),
            'phone': emergencyPhoneController.text.trim(),
            'relation': emergencyRelationController.text.trim(),
          }
        ],
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile: $e')),
      );
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
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update My Info'),
      ),
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
                  DropdownMenuItem(value: 'senior', child: Text('Senior')),
                  DropdownMenuItem(value: 'caregiver', child: Text('Caregiver')),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  onPressed: saveProfile,
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