import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService().init();

  final tts = FlutterTts();
  await tts.setLanguage('en-US');
  await tts.setSpeechRate(0.45);
  await tts.setVolume(1.0);

  NotificationService.onNotificationTapped = (ttsText) async {
    await tts.speak(ttsText);
  };

  runApp(const CareCompanionApp());
}
