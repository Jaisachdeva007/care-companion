import 'package:flutter/material.dart';
import 'assistant_questionnaire_screen.dart';
import 'manual_questionnaire_screen.dart';


class OnboardingChoiceScreen extends StatelessWidget {
  const OnboardingChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'How would you like to complete your care setup?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You can fill it out manually or let a guided assistant ask you questions one by one.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),

            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: const Icon(Icons.edit_document, size: 36),
                title: const Text(
                  'Fill Manually',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Complete the questionnaire using a form.',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManualQuestionnaireScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: const Icon(Icons.smart_toy_outlined, size: 36),
                title: const Text(
                  'Guided Assistant',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Answer one question at a time in a simpler guided flow.',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssistantQuestionnaireScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}