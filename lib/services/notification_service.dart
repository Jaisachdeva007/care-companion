import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> scheduleMedicationReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
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
        iOS: DarwinNotificationDetails(
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
    for (int i = 0; i < scheduleTimes.length; i++) {
      final nextTime = nextDateTimeFrom24Hour(scheduleTimes[i]);
      if (nextTime == null) continue;

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000 + i;

      await scheduleMedicationReminder(
        id: id,
        title: 'Medication Reminder',
        body: 'Time to take $medicationName ($dosage)',
        dateTime: nextTime,
      );
    }
  }

  Future<void> scheduleRefillReminder({
    required String medicationName,
    required DateTime refillDate,
  }) async {
    final reminderDate = refillDate.subtract(const Duration(days: 3));

    if (!reminderDate.isAfter(DateTime.now())) return;

    final id = refillDate.millisecondsSinceEpoch ~/ 1000;

    await scheduleMedicationReminder(
      id: id,
      title: 'Refill Reminder',
      body: 'Your medication "$medicationName" may need a refill soon.',
      dateTime: reminderDate,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}