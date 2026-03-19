import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget dashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.teal, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Care Companion'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Welcome Back!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          dashboardCard(
            icon: Icons.medication,
            title: 'Medication Reminders',
            subtitle: 'Track and manage daily medications',
          ),
          dashboardCard(
            icon: Icons.monitor_heart,
            title: 'Vitals Logging',
            subtitle: 'Record blood pressure, sugar, heart rate, and weight',
          ),
          dashboardCard(
            icon: Icons.mood,
            title: 'Mood Check-In',
            subtitle: 'Log daily mood and emotional wellbeing',
          ),
          dashboardCard(
            icon: Icons.warning,
            title: 'Emergency SOS',
            subtitle: 'Quickly contact help in emergencies',
          ),
          dashboardCard(
            icon: Icons.people,
            title: 'Caregiver Dashboard',
            subtitle: 'Keep family and caregivers informed',
          ),
        ],
      ),
    );
  }
}