// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mindmate/services/user_session.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:math';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get notifications => _notifications;

  /// Initialize notifications, channel, timezone
  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_reminder_channel',
      'Daily Reminder',
      description: 'Reminds the user to check in with MindMate daily.',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    print("🔔 NotificationService initialized (Asia/Manila)");
  }

  /// Request system permission (Android 13+/iOS as needed)
  static Future<bool> requestPermission() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final granted =
        await androidImplementation?.requestNotificationsPermission() ?? false;
    print("🔐 Notification permission granted: $granted");
    return granted;
  }

  /// Cancel all scheduled notifications
  static Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
    print("🛑 All reminders cancelled");
  }

  /// Reset reminders: cancel + schedule according to saved times
  static Future<void> resetReminders({String? userName}) async {
    print("🔄 resetReminders() called");
    final enabled = await UserSession.getNotifEnabled();
    if (!enabled) {
      print("⚠️ Notifications disabled — skipping schedule");
      await cancelAllReminders();
      return;
    }

    // ✅ Fetch user's first name
    final userName = await UserSession.getFirstName();

    // get saved times (or defaults)
    final times = await UserSession.getReminderTimes(); // [morning, afternoon, evening]
    await scheduleDailyReminders(userName: userName, times: times);
  }

  /// Core scheduler: accepts list of TimeOfDay (length 3 expected)
  static Future<void> scheduleDailyReminders({
    String? userName,
    List<TimeOfDay>? times,
  }) async {
    // Cancel existing before scheduling
    await _notifications.cancelAll();

    final reminderTimes = times ??
        [
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 17, minute: 0),
          const TimeOfDay(hour: 21, minute: 0),
        ];

    final random = Random();

    final morningMessages = [
      "Good morning ${userName ?? 'friend'} 🌅 How’s your mood today?",
      "Rise and shine ☀️ A new day, a new feeling — how do you feel?",
      "Hey ${userName ?? 'there'}! 🌞 Take a moment to check in with yourself.",
    ];

    final afternoonMessages = [
      "Hey ${userName ?? 'friend'} 👋 How’s your day going so far?",
      "Need a quick reset? 🌿 Log your mood and take a deep breath.",
      "Afternoon vibes check 🌇 — how are you holding up?",
    ];

    final eveningMessages = [
      "Good evening ${userName ?? 'friend'} 🌙 Time to unwind and reflect.",
      "Before bed 💭 take a moment for yourself — how was your day?",
      "You’ve made it through today, ${userName ?? 'friend'} 💖 How are you feeling?",
    ];

    final reinforcementMessages = [
      "You're doing amazing keeping track of your moods 🌟",
      "Consistency builds awareness 💪 Keep logging!",
      "Great job staying mindful of your emotions 💖",
    ];

    final titles = [
      "Morning Mindset 🌞",
      "Afternoon Pause 🌿",
      "Evening Reflection 🌙",
    ];

    // Ensure we only schedule up to the number of provided times (but default is 3)
    for (int i = 0; i < reminderTimes.length; i++) {
      final t = reminderTimes[i];
      final message = switch (i) {
        0 => morningMessages[random.nextInt(morningMessages.length)],
        1 => afternoonMessages[random.nextInt(afternoonMessages.length)],
        2 => eveningMessages[random.nextInt(eveningMessages.length)],
        _ => "How are you feeling today?",
      };

      final finalMessage =
          "$message\n${reinforcementMessages[random.nextInt(reinforcementMessages.length)]}";

      await _notifications.zonedSchedule(
        i, // id per reminder slot (0,1,2)
        titles[i % titles.length],
        finalMessage,
        _nextInstanceOfTime(t.hour, t.minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel',
            'Daily Reminder',
            channelDescription: 'Reminds the user to log their mood daily.',
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print("✅ Scheduled reminder $i at ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}");
    }
  }

  /// Helper: next TZ instance of given time in local zone
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
