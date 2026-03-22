import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSaving = false;
  bool _isInitializing = true;
  bool _awaitingConfirmation = false;
  bool _showManualCorrection = false;

  int _currentQuestionIndex = 0;
  String _currentTranscript = '';

  final TextEditingController _manualCorrectionController =
      TextEditingController();

  final List<Map<String, String>> _questions = [
    {
      'key': 'preferredName',
      'question': 'Hi, what name would you like me to call you?'
    },
    {
      'key': 'age',
      'question': 'What is your age?'
    },
    {
      'key': 'healthConditions',
      'question': 'Do you have any health conditions I should know about?'
    },
    {
      'key': 'allergies',
      'question': 'Do you have any allergies?'
    },
    {
      'key': 'medications',
      'question': 'What medications are you taking?'
    },
    {
      'key': 'mobilityNeeds',
      'question':
          'Do you use any mobility support, like a walker, wheelchair, cane, or something else?'
    },
    {
      'key': 'largeTextEnabled',
      'question': 'Would you like larger text in the app? Please say yes or no.'
    },
    {
      'key': 'voiceAssistantEnabled',
      'question':
          'Would you like voice guidance in the app? Please say yes or no.'
    },
  ];

  final Map<String, dynamic> _answers = {
    'preferredName': '',
    'age': '',
    'healthConditions': <String>[],
    'allergies': <String>[],
    'medications': <String>[],
    'mobilityNeeds': '',
    'largeTextEnabled': false,
    'voiceAssistantEnabled': true,
    'inputPreference': 'voice',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initVoiceFlow();
    });
  }

  Future<void> _initVoiceFlow() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          debugPrint('Speech status: $status');

          if (status == 'listening') {
            setState(() {
              _isListening = true;
            });
          } else if (status == 'done' || status == 'notListening') {
            _handleSpeechFinished();
          } else {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech error: ${error.errorMsg}')),
          );
        },
      );

      await _tts.setLanguage('en-US');
      await _setBestVoice();
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });

      if (_speechAvailable) {
        await _speakCurrentQuestion();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available on this device.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Voice init error: $e');
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start voice assistant: $e')),
      );
    }
  }

  Future<void> _setBestVoice() async {
    try {
      final voices = await _tts.getVoices;

      if (voices is List) {
        for (final voice in voices) {
          final voiceMap = Map<String, dynamic>.from(voice);
          final name = (voiceMap['name'] ?? '').toString().toLowerCase();
          final locale = (voiceMap['locale'] ?? '').toString().toLowerCase();

          if (locale.contains('en-us') &&
              (name.contains('samantha') ||
                  name.contains('ava') ||
                  name.contains('allison'))) {
            await _tts.setVoice({
              'name': voiceMap['name'],
              'locale': voiceMap['locale'],
            });
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Voice selection error: $e');
    }
  }

  Future<void> _speakCurrentQuestion() async {
    final question = _questions[_currentQuestionIndex]['question']!;
    try {
      await _tts.stop();
      await _tts.speak(question);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  Future<void> _speakConfirmation() async {
    final key = _questions[_currentQuestionIndex]['key']!;
    final answer = _currentTranscript.trim();

    String message = 'I heard $answer. Is that correct?';

    if (key == 'preferredName') {
      message =
          'I heard $answer. Is that correct? If not, you can spell your name or type it.';
    }

    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (e) {
      debugPrint('TTS confirmation error: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not available.')),
      );
      return;
    }

    try {
      setState(() {
        _currentTranscript = '';
        _awaitingConfirmation = false;
        _showManualCorrection = false;
      });

      await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _currentTranscript = result.recognizedWords;
        });
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        autoPunctuation: false,
        cancelOnError: true,
      ),
      pauseFor: const Duration(seconds: 2),
      listenFor: const Duration(seconds: 8),
    );
    } catch (e) {
      debugPrint('Start listening error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start listening: $e')),
      );
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _awaitingConfirmation = _currentTranscript.trim().isNotEmpty;
        _showManualCorrection = false;
        _manualCorrectionController.text = _currentTranscript;
      });

      if (_awaitingConfirmation) {
        await _speakConfirmation();
      }
    } catch (e) {
      debugPrint('Stop listening error: $e');
    }
  }

  void _handleSpeechFinished() {
    if (!mounted) return;

    if (_currentTranscript.trim().isNotEmpty) {
      setState(() {
        _isListening = false;
        _awaitingConfirmation = true;
        _showManualCorrection = false;
        _manualCorrectionController.text = _currentTranscript;
      });

      _speakConfirmation();
    } else {
      setState(() {
        _isListening = false;
      });
    }
  }

  List<String> _splitCommaOrAnd(String value) {
    return value
        .split(RegExp(r',| and ', caseSensitive: false))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool _parseYesNo(String value) {
    final lower = value.toLowerCase();
    return lower.contains('yes') ||
        lower.contains('yeah') ||
        lower.contains('yep') ||
        lower.contains('sure');
  }

  void _saveCurrentAnswer() {
    final key = _questions[_currentQuestionIndex]['key']!;
    final answer = _currentTranscript.trim();

    if (key == 'healthConditions' ||
        key == 'allergies' ||
        key == 'medications') {
      _answers[key] = _splitCommaOrAnd(answer);
    } else if (key == 'largeTextEnabled' || key == 'voiceAssistantEnabled') {
      _answers[key] = _parseYesNo(answer);
    } else {
      _answers[key] = answer;
    }
  }

  Future<void> _nextQuestion() async {
    if (_awaitingConfirmation) return;

    if (_currentTranscript.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer the question first.')),
      );
      return;
    }

    _saveCurrentAnswer();

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _currentTranscript = '';
        _awaitingConfirmation = false;
        _showManualCorrection = false;
        _manualCorrectionController.clear();
      });
      await _speakCurrentQuestion();
    } else {
      await _saveToFirestore();
    }
  }

  void _confirmAnswer() {
    setState(() {
      _awaitingConfirmation = false;
      _showManualCorrection = false;
    });
    _nextQuestion();
  }

  void _retryAnswer() {
    setState(() {
      _currentTranscript = '';
      _awaitingConfirmation = false;
      _showManualCorrection = false;
      _manualCorrectionController.clear();
    });
  }

  void _useManualCorrection() {
    setState(() {
      _showManualCorrection = true;
      _manualCorrectionController.text = _currentTranscript;
    });
  }

  void _saveManualCorrection() {
    setState(() {
      _currentTranscript = _manualCorrectionController.text.trim();
      _showManualCorrection = false;
    });
  }

  void _spellNameMode() {
    setState(() {
      _showManualCorrection = true;
      _manualCorrectionController.clear();
    });
  }

  Future<void> _saveToFirestore() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;

      await FirestoreService().saveQuestionnaire(
        uid: user.uid,
        preferredName: _answers['preferredName'] ?? '',
        age: _answers['age'] ?? '',
        healthConditions: List<String>.from(_answers['healthConditions'] ?? []),
        allergies: List<String>.from(_answers['allergies'] ?? []),
        medications: List<String>.from(_answers['medications'] ?? []),
        mobilityNeeds: _answers['mobilityNeeds'] ?? '',
        inputPreference: 'voice',
        voiceAssistantEnabled: _answers['voiceAssistantEnabled'] ?? true,
        largeTextEnabled: _answers['largeTextEnabled'] ?? false,
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
        SnackBar(content: Text('Could not save answers: $e')),
      );
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    try {
      _speech.stop();
    } catch (_) {}

    try {
      _tts.stop();
    } catch (_) {}

    _manualCorrectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestionIndex]['question']!;
    final stepLabel =
        'Question ${_currentQuestionIndex + 1} of ${_questions.length}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Talk to Care Companion'),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    stepLabel,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: (_currentQuestionIndex + 1) / _questions.length,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    question,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.teal.shade200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _currentTranscript.isEmpty
                          ? 'Your spoken answer will appear here.'
                          : _currentTranscript,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_awaitingConfirmation) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isListening ? null : _startListening,
                            icon: const Icon(Icons.mic),
                            label: Text(
                              _isListening ? 'Listening...' : 'Start Talking',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _speakCurrentQuestion,
                            icon: const Icon(Icons.volume_up),
                            label: const Text('Repeat Question'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_awaitingConfirmation) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Please confirm your answer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _confirmAnswer,
                            child: const Text('Yes, Continue'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _retryAnswer,
                            child: const Text('No, Try Again'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _useManualCorrection,
                            child: const Text('Type Correction'),
                          ),
                        ),
                      ],
                    ),
                    if (_questions[_currentQuestionIndex]['key'] ==
                        'preferredName') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _spellNameMode,
                              child: const Text('Spell My Name'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  if (_showManualCorrection) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _manualCorrectionController,
                      decoration: const InputDecoration(
                        labelText: 'Correct your answer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveManualCorrection,
                            child: const Text('Use This Answer'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isSaving || _awaitingConfirmation)
                          ? null
                          : _nextQuestion,
                      child: _isSaving
                          ? const CircularProgressIndicator()
                          : Text(
                              _currentQuestionIndex == _questions.length - 1
                                  ? 'Finish Setup'
                                  : 'Next Question',
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}