import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'edit_health_info_screen.dart';
import 'medication_list_screen.dart'; 
import '../services/notification_service.dart';
import 'emergency_services_screen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final authService = AuthService();

    return StreamBuilder(
      stream: FirestoreService().getUserStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const Scaffold(
            body: Center(child: Text('No user data found')),
          );
        }

        final userData = snapshot.data!.data()!;
        final fullName = userData['fullName'] ?? '';
        final role = userData['role'] ?? 'senior';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Care Companion'),
          ),

          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(fullName.isEmpty ? 'User' : fullName),
                  accountEmail: Text(user.email ?? ''),
                  currentAccountPicture: const CircleAvatar(
                    child: Icon(Icons.person, size: 32),
                  ),
                ),

                // HOME
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Home'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.emergency),
                    title: const Text('Emergency Services'),
                    subtitle: const Text('Find nearby hospital, ER, clinic, and pharmacy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                    MaterialPageRoute(
                          builder: (context) => const EmergencyServicesScreen(),
                        ),
                      );
                    },
                  ),
                ),

                // PROFILE
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Update My Info'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),

                // HEALTH INFO
                ListTile(
                  leading: const Icon(Icons.health_and_safety),
                  title: const Text('Update Health Info'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditHealthInfoScreen(),
                      ),
                    );
                  },
                ),

                // ✅ NEW: MEDICATIONS
                ListTile(
                  leading: const Icon(Icons.medication),
                  title: const Text('Medications'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MedicationListScreen(),
                      ),
                    );
                  },
                ),

                const Divider(),

                // LOGOUT
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log Out'),
                  onTap: () async {
                    Navigator.pop(context);
                    await authService.logout();

                    if (!context.mounted) return;

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),

          // BODY
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome $fullName',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Role: $role',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your care dashboard is ready.',
                  style: TextStyle(fontSize: 16),
                  
                ),
                const SizedBox(height: 20),
                
              ],
            ),
          ),
        );
      },
    );
  }
}