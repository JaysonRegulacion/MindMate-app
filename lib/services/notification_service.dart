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

  /// -------------------------------
  /// 🔔 Initialize notifications, channel, timezone
  /// -------------------------------
  static Future<void> initialize() async {
    print("🚀 Initializing NotificationService...");

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(settings: initSettings);
    print("📦 FlutterLocalNotifications initialized");

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

    print("📣 Android notification channel created");

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    print("🌏 Timezone initialized → Asia/Manila");
  }

  /// -------------------------------
  /// 🔐 Request notification permission
  /// -------------------------------
  static Future<bool> requestPermission() async {
    print("🔐 Requesting notification permission...");

    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final granted =
        await androidImplementation?.requestNotificationsPermission() ?? false;

    print("🔐 Notification permission granted: $granted");
    return granted;
  }

  /// -------------------------------
  /// 🛑 Cancel all scheduled reminders
  /// -------------------------------
  static Future<void> cancelAllReminders() async {
    print("🛑 Cancelling all scheduled notifications...");
    await _notifications.cancelAll();
    print("🗑️ All notifications cancelled");
  }

  /// -------------------------------
  /// 🔄 Reset reminders (main entry point)
  /// -------------------------------
  static Future<void> resetReminders({String? userName}) async {
    print("🔄 resetReminders() CALLED");

    final enabled = await UserSession.getNotifEnabled();
    print("🔔 Notifications enabled (prefs): $enabled");

    if (!enabled) {
      print("⛔ Notifications disabled → cancelling reminders");
      await cancelAllReminders();
      return;
    }

    final resolvedName = await UserSession.getFirstName();
    print("👤 Resolved userName: $resolvedName");

    final times = await UserSession.getReminderTimes();
    print("⏰ Loaded reminder times: $times");

    await scheduleDailyReminders(
      userName: resolvedName,
      times: times,
    );

    print("✅ resetReminders() COMPLETED");
  }

  /// -------------------------------
  /// 📆 Core scheduler
  /// -------------------------------
  static Future<void> scheduleDailyReminders({
    String? userName,
    List<TimeOfDay>? times,
  }) async {
    print("📆 scheduleDailyReminders() START");

    await _notifications.cancelAll();
    print("🗑️ Existing notifications cancelled before scheduling");

    final reminderTimes = times ??
        [
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 17, minute: 0),
          const TimeOfDay(hour: 21, minute: 0),
        ];

    print("⏳ Final reminderTimes: $reminderTimes");
    print("👤 userName used: $userName");

    final random = Random();

    final morningMessages = [
      "Good morning ${userName ?? 'friend'} 🌅 How’s your mood today?",
      "Rise and shine ☀️ A new day, a new feeling — how do you feel?",
      "Hey ${userName ?? 'there'}! 🌞 Take a moment to check in with yourself.",
    ];

    final afternoonMessages = [
      "Hey ${userName ?? 'friend'} 👋 How’s your day going so far?",
      "Need a quick reset? 🌿 Journal your thoughts and take a deep breath.",
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

      final scheduledTime = _nextInstanceOfTime(t.hour, t.minute);

      print(
        "⏰ Scheduling reminder #$i "
        "for ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} "
        "→ $scheduledTime",
      );

      await _notifications.zonedSchedule(
        id: i,
        title: titles[i % titles.length],
        body: finalMessage,
        scheduledDate: scheduledTime,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel',
            'Daily Reminder',
            channelDescription: 'Reminds the user to log their journal daily.',
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print("✅ Reminder #$i scheduled successfully");
    }

    print("📆 scheduleDailyReminders() END");
  }

  /// -------------------------------
  /// 🕰️ Next scheduled time helper
  /// -------------------------------
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    print(
      "🕰️ _nextInstanceOfTime() "
      "now=$now "
      "requested=$hour:$minute "
      "final=$scheduledDate",
    );

    return scheduledDate;
  }
}
