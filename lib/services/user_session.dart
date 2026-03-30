// lib/services/user_session.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  // ---------- existing Hive-based functions (unchanged) ----------
  static Future<Box> _getBox() async {
    if (!Hive.isBoxOpen('userBox')) {
      return await Hive.openBox('userBox');
    }
    return Hive.box('userBox');
  }

  /// Save user credentials for offline login
  static Future<void> saveUser(String id, String email, String password) async {
    var box = await _getBox();
    final hashedPassword = sha256.convert(utf8.encode(password)).toString();
    final expiry = DateTime.now().add(const Duration(days: 7)).toIso8601String();

    await box.put('userId', id);
    await box.put('email', email);
    await box.put('password', hashedPassword);
    await box.put('isLoggedIn', true);
    await box.put('expiry', expiry);
  }

  /// Save Supabase profile data (firstName with expiry)
  static Future<void> saveUserProfile(String firstName) async {
    var box = await _getBox();
    await box.put('firstName', firstName);
    await box.put(
      'firstNameExpiry',
      DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    );
    print("✅ Saved firstName: $firstName (expires in 7 days)");
  }

  /// Get stored firstName (only if not expired)
  static Future<String?> getFirstName() async {
    var box = await _getBox();
    final firstName = box.get('firstName');
    final expiry = box.get('firstNameExpiry');

    if (expiry != null && DateTime.parse(expiry).isBefore(DateTime.now())) {
      await box.delete('firstName');
      await box.delete('firstNameExpiry');
      return null; // expired
    }
    print("📦 Retrieved firstName: $firstName");
    return firstName;
  }

  /// Verify offline login credentials
  static Future<String?> verifyOfflineLogin(String email, String password) async {
    var box = await _getBox();
    final storedEmail = box.get('email');
    final storedPassword = box.get('password');
    final expiry = box.get('expiry');

    if (expiry != null && DateTime.parse(expiry).isBefore(DateTime.now())) {
      return "expired"; // 🔹 session expired
    }

    final hashedInput = sha256.convert(utf8.encode(password)).toString();
    if (email == storedEmail && hashedInput == storedPassword) {
      return "valid"; // 🔹 success
    }

    return "invalid"; // 🔹 wrong credentials
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    var box = await _getBox();
    return box.get('isLoggedIn', defaultValue: false);
  }

  /// Clear all saved user session data (for logout or password reset)
  static Future<void> clearUserSession() async {
    var box = await _getBox();

    // Delete only user-related keys
    await box.delete('userId');
    await box.delete('email');
    await box.delete('password');
    await box.delete('isLoggedIn');
    await box.delete('expiry');
    await box.delete('firstName');
    await box.delete('firstNameExpiry');

    print("🗑️ User session cleared");
  }

  /// -------------------------------
  /// 📓 First journal notification logic
  /// -------------------------------

  /// Mark that the user has logged at least one journal
  static Future<void> setFirstJournalLogged() async {
    var box = await _getBox();
    await box.put('hasJournalLogged', true);
  }

  /// Check if user has logged at least one journal
  static Future<bool> hasJournalLogged() async {
    var box = await _getBox();
    return box.get('hasJournalLogged', defaultValue: false);
  }

  /// Mark notification prompt as shown
  static Future<void> setNotificationPromptShown() async {
    var box = await _getBox();
    await box.put('notificationPromptShown', true);
  }

  /// Check if notification prompt was already shown
  static Future<bool> isNotificationPromptShown() async {
    var box = await _getBox();
    return box.get('notificationPromptShown', defaultValue: false);
  }

  /// Mark that the user has logged at least one mood
  static Future<void> setMoodLogged() async {
    var box = await _getBox();
    await box.put('hasMoodLogged', true);
  }

  /// Check if the user has logged at least one mood
  static Future<bool> hasMoodLogged() async {
    var box = await _getBox();
    return box.get('hasMoodLogged', defaultValue: false);
  }

  // ---------- SharedPreferences-based notification settings ----------
  // Keys
  static const _notifEnabledKey = 'notif_enabled';
  static const _morningHourKey = 'morning_hour';
  static const _morningMinuteKey = 'morning_min';
  static const _afternoonHourKey = 'afternoon_hour';
  static const _afternoonMinuteKey = 'afternoon_min';
  static const _eveningHourKey = 'evening_hour';
  static const _eveningMinuteKey = 'evening_min';
  static const _reminderModeKey = 'reminder_mode'; // new

  /// Save notification enabled/disabled
  static Future<void> saveNotifEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifEnabledKey, enabled);
  }

  /// Get notification enabled (default false)
  static Future<bool> getNotifEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifEnabledKey) ?? false;
  }

  /// Save morning time
  static Future<void> saveMorningTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_morningHourKey, time.hour);
    await prefs.setInt(_morningMinuteKey, time.minute);
  }

  /// Get morning time (default 09:00)
  static Future<TimeOfDay> getMorningTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_morningHourKey) ?? 9;
    final minute = prefs.getInt(_morningMinuteKey) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Save afternoon time
  static Future<void> saveAfternoonTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_afternoonHourKey, time.hour);
    await prefs.setInt(_afternoonMinuteKey, time.minute);
  }

  /// Get afternoon time (default 17:00)
  static Future<TimeOfDay> getAfternoonTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_afternoonHourKey) ?? 17;
    final minute = prefs.getInt(_afternoonMinuteKey) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Save evening time
  static Future<void> saveEveningTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_eveningHourKey, time.hour);
    await prefs.setInt(_eveningMinuteKey, time.minute);
  }

  /// Get evening time (default 21:00)
  static Future<TimeOfDay> getEveningTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_eveningHourKey) ?? 21;
    final minute = prefs.getInt(_eveningMinuteKey) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Convenience: get all three times (with defaults)
  static Future<List<TimeOfDay>> getReminderTimes() async {
    final morning = await getMorningTime();
    final afternoon = await getAfternoonTime();
    final evening = await getEveningTime();
    return [morning, afternoon, evening];
  }

  /// -------------------------------
  /// 🔔 Reminder mode (default/custom)
  /// -------------------------------
  static Future<void> saveReminderMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderModeKey, mode);
  }

  static Future<String> getReminderMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_reminderModeKey) ?? "default";
  }
}
