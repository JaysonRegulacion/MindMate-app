// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:mindmate/services/notification_service.dart';
import 'package:mindmate/services/user_session.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationsEnabled = false;
  String reminderMode = "default"; // default/custom
  TimeOfDay morning = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay afternoon = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay evening = const TimeOfDay(hour: 21, minute: 0);

  bool _loading = true;

  final TimeOfDay morningStart = const TimeOfDay(hour: 5, minute: 0);
  final TimeOfDay morningEnd = const TimeOfDay(hour: 11, minute: 59);
  final TimeOfDay afternoonStart = const TimeOfDay(hour: 12, minute: 0);
  final TimeOfDay afternoonEnd = const TimeOfDay(hour: 17, minute: 59);
  final TimeOfDay eveningStart = const TimeOfDay(hour: 18, minute: 0);
  final TimeOfDay eveningEnd = const TimeOfDay(hour: 21, minute: 59);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await UserSession.getNotifEnabled();
    final times = await UserSession.getReminderTimes();
    final mode = await UserSession.getReminderMode();

    setState(() {
      isNotificationsEnabled = enabled;
      morning = times[0];
      afternoon = times[1];
      evening = times[2];
      reminderMode = mode;
      _loading = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Permission required"),
            content: const Text(
                "Please allow notifications in system settings to receive reminders."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK")),
            ],
          ),
        );
        return;
      }
    }

    await UserSession.saveNotifEnabled(value);
    setState(() {
      isNotificationsEnabled = value;
    });

    if (value) {
      await NotificationService.resetReminders();
    } else {
      await NotificationService.cancelAllReminders();
    }
  }

  bool _isValidTime(TimeOfDay time, String label) {
    int minutes = time.hour * 60 + time.minute;
    switch (label) {
      case 'Morning':
        return minutes >= morningStart.hour * 60 + morningStart.minute &&
            minutes <= morningEnd.hour * 60 + morningEnd.minute;
      case 'Afternoon':
        return minutes >= afternoonStart.hour * 60 + afternoonStart.minute &&
            minutes <= afternoonEnd.hour * 60 + afternoonEnd.minute;
      case 'Evening':
        return minutes >= eveningStart.hour * 60 + eveningStart.minute &&
            minutes <= eveningEnd.hour * 60 + eveningEnd.minute;
      default:
        return false;
    }
  }

  Future<void> _pickTime({
    required TimeOfDay current,
    required String label,
    required Function(TimeOfDay) onSaved,
  }) async {
    final newTime = await showTimePicker(
      context: context,
      initialTime: current,
    );

    if (newTime != null) {
      if (!_isValidTime(newTime, label)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$label reminder must be within allowed range.')),
        );
        return;
      }

      await onSaved(newTime);
      if (label == 'Morning') {
        await UserSession.saveMorningTime(newTime);
        morning = newTime;
      } else if (label == 'Afternoon') {
        await UserSession.saveAfternoonTime(newTime);
        afternoon = newTime;
      } else {
        await UserSession.saveEveningTime(newTime);
        evening = newTime;
      }

      if (await UserSession.getNotifEnabled()) {
        await NotificationService.resetReminders();
      }

      setState(() {});
    }
  }

  Future<void> _setReminderMode(String mode) async {
    await UserSession.saveReminderMode(mode);
    setState(() {
      reminderMode = mode;
    });

    if (mode == "default") {
      morning = const TimeOfDay(hour: 9, minute: 0);
      afternoon = const TimeOfDay(hour: 17, minute: 0);
      evening = const TimeOfDay(hour: 21, minute: 0);

      await UserSession.saveMorningTime(morning);
      await UserSession.saveAfternoonTime(afternoon);
      await UserSession.saveEveningTime(evening);
    }

    if (await UserSession.getNotifEnabled()) {
      await NotificationService.resetReminders();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Settings")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SwitchListTile(
            title: const Text("Enable Daily Reminders"),
            subtitle: const Text("Receive notifications to log your mood"),
            value: isNotificationsEnabled,
            onChanged: (v) => _toggleNotifications(v),
          ),
          const Divider(),
          if (isNotificationsEnabled)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: const Text("Use Default Reminders"),
                  leading: Radio<String>(
                    value: "default",
                    groupValue: reminderMode,
                    onChanged: (v) => _setReminderMode(v!),
                  ),
                  onTap: () => _setReminderMode("default"),
                ),
                ListTile(
                  title: const Text("Customize Reminders"),
                  leading: Radio<String>(
                    value: "custom",
                    groupValue: reminderMode,
                    onChanged: (v) => _setReminderMode(v!),
                  ),
                  onTap: () => _setReminderMode("custom"),
                ),
                if (reminderMode == "custom") ...[
                  ListTile(
                    title: const Text("Morning Reminder"),
                    subtitle: Text("${morning.format(context)} • Allowed: 5:00 AM - 11:59 AM"),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _pickTime(
                        current: morning,
                        label: 'Morning',
                        onSaved: (t) => morning = t),
                  ),
                  ListTile(
                    title: const Text("Afternoon Reminder"),
                    subtitle: Text("${afternoon.format(context)} • Allowed: 12:00 PM - 5:59 PM"),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _pickTime(
                        current: afternoon,
                        label: 'Afternoon',
                        onSaved: (t) => afternoon = t),
                  ),
                  ListTile(
                    title: const Text("Evening Reminder"),
                    subtitle: Text("${evening.format(context)} • Allowed: 6:00 PM - 9:59 PM"),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _pickTime(
                        current: evening,
                        label: 'Evening',
                        onSaved: (t) => evening = t),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Tips: You can choose default reminders or customize your own times. If notifications are disabled, reminders won't be scheduled.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}
