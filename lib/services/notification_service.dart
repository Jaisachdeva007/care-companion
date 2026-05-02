import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  static Function(String ttsText)? onNotificationTapped;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTapped?.call(payload);
        }
      },
    );
  }

  Future<void> scheduleMedicationReminder({
    required int id,
    required String title,
    required String body,
    required String ttsText,
    required DateTime dateTime,
  }) async {
    if (kIsWeb) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(dateTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel',
          'Medication Reminders',
          channelDescription: 'Medication reminder notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: ttsText,
    );
  }

  DateTime? nextDateTimeFrom24Hour(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length != 2) return null;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = DateTime.now();

      DateTime scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      return scheduled;
    } catch (_) {
      return null;
    }
  }

  Future<void> scheduleMedicationTimes({
    required String medicationName,
    required String dosage,
    required List<String> scheduleTimes,
  }) async {
    if (kIsWeb) return;

    for (int i = 0; i < scheduleTimes.length; i++) {
      final nextTime = nextDateTimeFrom24Hour(scheduleTimes[i]);
      if (nextTime == null) continue;

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000 + i;

      final ttsText =
          'It is time to take your $medicationName. You need to take $dosage.';

      await scheduleMedicationReminder(
        id: id,
        title: 'Medication Reminder 💊',
        body: 'Time to take $medicationName — $dosage',
        ttsText: ttsText,
        dateTime: nextTime,
      );
    }
  }

  Future<void> scheduleRefillReminder({
    required String medicationName,
    required DateTime refillDate,
  }) async {
    if (kIsWeb) return;

    final reminderDate = refillDate.subtract(const Duration(days: 3));

    if (!reminderDate.isAfter(DateTime.now())) return;

    final id = refillDate.millisecondsSinceEpoch ~/ 1000;

    final ttsText =
        'Reminder: your $medicationName may need a refill soon. Please check your supply.';

    await scheduleMedicationReminder(
      id: id,
      title: 'Refill Reminder',
      body: '$medicationName may need a refill soon.',
      ttsText: ttsText,
      dateTime: reminderDate,
    );
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}