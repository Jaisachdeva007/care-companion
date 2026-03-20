import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class AssistantQuestionnaireScreen extends StatefulWidget {
  const AssistantQuestionnaireScreen({super.key});

  @override
  State<AssistantQuestionnaireScreen> createState() =>
      _AssistantQuestionnaireScreenState();
}

class _AssistantQuestionnaireScreenState
    extends State<AssistantQuestionnaireScreen> {
  int currentStep = 0;
  final TextEditingController answerController = TextEditingController();

  final List<String> questions = [
    'What name would you like us to call you?',
    'What is your age?',
    'Do you have any health conditions? Separate them with commas if there are multiple.',
    'Do you have any allergies? Separate them with commas if there are multiple.',
    'What medications are you taking? Separate them with commas if there are multiple.',
    'Do you have any mobility needs? For example walker, wheelchair, cane, or none.',
  ];

  final Map<String, String> answers = {};
  bool isSaving = false;

  Future<void> nextQuestion() async {
    final currentAnswer = answerController.text.trim();
    if (currentAnswer.isEmpty) return;

    answers[questions[currentStep]] = currentAnswer;

    if (currentStep < questions.length - 1) {
      setState(() {
        currentStep++;
        answerController.clear();
      });
    } else {
      await saveQuestionnaire();
    }
  }

  Future<void> saveQuestionnaire() async {
    setState(() {
      isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;

      await FirestoreService().saveQuestionnaire(
        uid: user.uid,
        preferredName: answers[questions[0]] ?? '',
        age: answers[questions[1]] ?? '',
        healthConditions: (answers[questions[2]] ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        allergies: (answers[questions[3]] ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        medications: (answers[questions[4]] ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        mobilityNeeds: answers[questions[5]] ?? '',
        inputPreference: 'guided',
        voiceAssistantEnabled: true,
        largeTextEnabled: false,
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
        isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guided Assistant'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Question ${currentStep + 1} of ${questions.length}',
                style: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              questions[currentStep],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: answerController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Type your answer here',
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : nextQuestion,
                child: isSaving
                    ? const CircularProgressIndicator()
                    : Text(
                        currentStep == questions.length - 1
                            ? 'Finish'
                            : 'Next',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}